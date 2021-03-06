# ${license-info}
# ${developer-info}
# ${author-info}

package NCM::Component::spma::yum;
#
# a few standard statements, mandatory for all components
#
use strict;
use warnings;
use NCM::Component;
our $EC=LC::Exception::Context->new->will_store_all;
our @ISA = qw(NCM::Component);
use EDG::WP4::CCM::Element qw(unescape);
use EDG::WP4::CCM::TextRender;
use CAF::Process;
use CAF::FileWriter;
use CAF::FileEditor;
use LC::Exception qw(SUCCESS);
use Set::Scalar;
use File::Path qw(mkpath);
use Text::Glob qw(match_glob);

use constant REPOS_DIR => "/etc/yum.repos.d";
use constant REPOS_TEMPLATE => "repository";
use constant REPOS_TREE => "/software/repositories";
use constant PKGS_TREE => "/software/packages";
use constant GROUPS_TREE => "/software/groups";
use constant CMP_TREE => "/software/components/${project.artifactId}";
use constant YUM_CMD => qw(yum -y shell);
use constant RPM_QUERY => [qw(rpm -qa --qf %{NAME}\n%{NAME};%{ARCH}\n)];
use constant REMOVE => "remove";
use constant INSTALL => "install";
use constant YUM_PLUGIN_DIR => "/etc/yum/pluginconf.d";
use constant YUM_PACKAGE_LIST => YUM_PLUGIN_DIR . "/versionlock.list";
use constant LEAF_PACKAGES => [qw(package-cleanup --leaves --all --qf %{NAME};%{ARCH})];
use constant YUM_EXPIRE => qw(yum clean expire-cache);
use constant YUM_PURGE_METADATA => qw(yum clean metadata);
use constant YUM_DISTRO_SYNC => qw(yum -y distro-sync);
use constant YUM_CONF_FILE => "/etc/yum.conf";
use constant CLEANUP_ON_REMOVE => "clean_requirements_on_remove";
use constant REPOQUERY => qw(repoquery --show-duplicates --envra);
use constant YUM_COMPLETE_TRANSACTION => qw(yum-complete-transaction -y);
use constant OBSOLETE => "obsoletes";
use constant REPO_DEPS => qw(repoquery --requires --resolve --plugins
                             --qf %{NAME};%{ARCH});
use constant REPO_WHATREQS => qw(repoquery --whatrequires --recursive --plugins
                                 --qf %{NAME}\n%{NAME};%{ARCH});
use constant SMALL_REMOVAL => 3;
use constant LARGE_INSTALL => 200;
use constant REPOGROUP => qw(repoquery -l -g --grouppkgs);

our $NoActionSupported = 1;

# If user packages are not allowed, removes any repositories present
# in the system that are not listed in $allowed_repos.
sub cleanup_old_repos
{
    my ($self, $repo_dir, $allowed_repos, $allow_user_pkgs) = @_;

    return 1 if $allow_user_pkgs;

    my $dir;
    if (!opendir($dir, $repo_dir)) {
        $self->error("Unable to read repositories in $repo_dir");
        return 0;
    }

    my $current = Set::Scalar->new(map(m{(.*)\.repo$}, readdir($dir)));

    closedir($dir);
    my $allowed = Set::Scalar->new(map($_->{name}, @$allowed_repos));
    my $rm = $current-$allowed;
    foreach my $i (@$rm) {
        # We use $f here to make Devel::Cover happy
        my $f = "$repo_dir/$i.repo";
        $self->verbose("Unlinking outdated repository $f");
        if (!unlink($f)) {
            $self->error("Unable to remove outdated repository $i: $!");
            return 0;
        }
    }
    return 1;
}

# Creates the repository dir if needed.
sub initialize_repos_dir
{
    my ($self, $repo_dir) = @_;
    if (! -d $repo_dir) {
        $self->verbose("$repo_dir didn't exist. Creating it");
        if (!eval{mkpath($repo_dir)} || $@) {
            $self->error("Unable to create repository dir $repo_dir: $@");
            return 0;
        }
    }
    return 1;
}

# Returns the URLs of the repositories listed in $prots, with their
# host part replaced by each of the reverse @proxies.
sub generate_reverse_proxy_urls
{
    my ($self, $prots, @proxies) = @_;

    my @l;
    foreach my $pt (@$prots) {
        foreach my $px (@proxies) {
            my $url = $pt->{url};
            $url =~ s{^(.*?):(/+)[^/]+}{$1:$2$px};
            push(@l, { url => $url });
        }
    }
    return \@l;
}

# Generate the URLs for the forward proxies, based on whether the
# repository is accessible over HTTP or HTTPS.
sub generate_forward_proxy_urls
{
    my ($self, $proto, @px) = @_;

    $proto->[0]->{url} =~ m{^(.*?):};
    return "$1://$px[0]";
}

# Generates the repository files in $repos_dir based on the contents
# of the $repos subtree. It uses Template::Toolkit $template to render
# the file. Optionally, proxy information will be used. In that case,
# it will use the $proxy host, wich is of $type "reverse" or
# "forward", and runs on the given $port.
# Returns undef on errors, or the number of repository files that were changed.
sub generate_repos
{
    my ($self, $repos_dir, $repos, $template, $proxy, $type, $port) = @_;

    my @px = split(",", $proxy) if $proxy;
    @px = map("$_:$port", @px) if $port;

    my $changes = 0;

    foreach my $repo (@$repos) {
        if (!exists($repo->{proxy}) && @px) {
            if ($type eq 'reverse') {
                $repo->{protocols} = $self->generate_reverse_proxy_urls($repo->{protocols}, @px);
            } else {
                $repo->{proxy} = $self->generate_forward_proxy_urls($repo->{protocols}, @px);
            }
        }

        # No log instance passed, do all the logging ourself.
        my $trd = EDG::WP4::CCM::TextRender->new($template, $repo, relpath => 'spma');
        if (! defined($trd->get_text())) {
            $self->error ("Unable to generate repository $repo->{name}: $trd->{fail}");
            return;
        };

        my $fh = $trd->filewriter("$repos_dir/$repo->{name}.repo",
                                  header => "# File generated by ", __PACKAGE__, ". Do not edit",
                                  log => $self);
        $changes += $fh->close() || 0; # handle undef

        $fh = CAF::FileWriter->new("$repos_dir/$repo->{name}.pkgs",
                                   log => $self);
        # TODO. Also add "do not edit" ? Or switch to FileEditor?
        print $fh "# Additional configuration for $repo->{name}\n";
        $fh->close();
    }

    return $changes;
}

=pod

=head2 C<execute_yum_command>

Executes C<$command> for reason C<$why>. Optionally with standard
input C<$stdin>.  The command may be executed even under --noaction if
C<$keeps_state> has a true value.

If the command is executed, this method returns its standard output
upon success or C<undef> in case of error.  If the command is not
executed the method always returns a true value (usually 1, but don't
rely on this!).

Yum-based commands require annoying error handling: they may exit 0
even upon errors.  In those cases, we have to detect errors by looking
at stderr.  This method just encapsulates all that logic, keeping the
callers clean.

=cut

sub execute_yum_command
{
    my ($self, $command, $why, $keeps_state, $stdin, $error_logger) = @_;

    $error_logger = "error" if (!($error_logger && $error_logger =~ m/^(error|warn|info|verbose)$/));

    my (%opts, $out, $err, @missing);

    %opts = ( log => $self,
          stdout => \$out,
          stderr => \$err,
          keeps_state => $keeps_state);

    $opts{stdin} = $stdin if defined($stdin);

    my $cmd = CAF::Process->new($command, %opts);

    $cmd->execute();
    $self->warn("$why produced warnings: $err") if $err;
    $self->verbose("$why output: $out") if(defined($out));
    if ($? ||
        ($err && $err =~ m{^(?:Error|Failed|
                      (?:Could \s+ not \s+ match)|
                      (?:Transaction \s+ encountered.*error)|
                      (?:Unknown \s+ group \s+  package \s+ type) |
                      (?:.*requested \s+ URL \s+ returned \s+ error))}oxmi) ||
        ($out && (@missing = ($out =~ m{^No package (.*) available}omg)))
        ) {
        $self->warn("Command output: $out");
        $self->$error_logger("Failed $why: ", $err || "(empty/undef stderr)");
        if (@missing) {
            $self->$error_logger("Missing packages: ", join(" ", @missing));
        }
        return undef;
    }
    return $cmd->{NoAction} || $out;
}


# Returns a yum shell line for $op-erating on the $target
# packages. $op is typically "install" or "remove".
sub schedule
{
    my ($self, $op, $target) = @_;

    return "" if !@$target;

    my @ls;
    foreach my $pkg (@$target) {
        push(@ls, $pkg);
        $ls[-1] =~ s{;}{.};
    }
    return  sprintf("%s %s\n", $op, join(" ", @ls));
}

# Returns a set of all installed packages
sub installed_pkgs
{
    my $self = shift;

    my $cmd = CAF::Process->new(RPM_QUERY, keeps_state => 1,
                log => $self);

    my $out = $cmd->output();
    if ($?) {
        return undef;
    }
    # We don't consider gpg-pubkeys, which won't come from any
    # downloaded RPM, anyways.
    my @pkgs = grep($_ !~ m{^gpg-pubkey.*\(none\)$}, split(/\n/, $out));

    return Set::Scalar->new(@pkgs);
}

# Returns the set of packages in all the $groups passed as arguments,
# or undef if ANY of the groups cannot be expanded.  For now it calls
# repoquery once per group.  I hope there will be few enough groups in
# the profile so that this isn't a performance bottleneck.
sub expand_groups
{
    my ($self, $groups) = @_;

    my $pkgs = Set::Scalar->new();

    while (my ($group, $types) = each(%$groups)) {
        my $what = join(",", grep($types->{$_}, keys(%$types)));
        my $lst = $self->execute_yum_command([REPOGROUP, $what, $group],
                                             "Group expansion", 1)
            or return undef;
        $pkgs->insert(split(/\n/, $lst));
    }
    return $pkgs;
}

# Returns a set with the desired packages.
sub wanted_pkgs
{
    my ($self, $pkgs) = @_;

    my @pkl;

    while (my ($pkg, $st) = each(%$pkgs)) {
        my ($name) = (unescape($pkg) =~ m{^([\w\.\-\+]+)[*?]?});
        if (!$name) {
            $self->error("Invalid package name: ", unescape($pkg));
            return undef;
        }
        if (%$st) {
            while (my ($ver, $archs) = each(%$st)) {
                push(@pkl, map("$name;$_", keys(%{$archs->{arch}})));
            }
        } else {
            push(@pkl, $name);
        }
    }
    return Set::Scalar->new(@pkl);
}

# Returns the yum shell command to apply the transaction. If run, the
# transaction will be applied. Otherwise it will just be solved and
# printed.
sub solve_transaction {
    my ($self, $run) = @_;

    my @rs = "transaction solve";
    if ($run && !$NoAction) {
        push(@rs, "transaction run");
    } else {
        push(@rs, "transaction reset");
    }
    return join("\n", @rs, "");
}

# Expires Yum caches before modifying the system.  Failure to do so
# would lead to recent packages not being seen or installed during the
# execution.  In the worst case, the package is an upgrade to an
# existing one, and either the old version is left around, or even
# worse, the old version is removed and the new version is not
# installed at all.
sub expire_yum_caches
{
    my ($self) = @_;

    return defined($self->execute_yum_command([YUM_EXPIRE], "clean up caches"));
}

# Actually calls yum to execute transaction $tx
sub apply_transaction
{

    my ($self, $tx, $tx_error_is_warn) = @_;

    $self->debug(5, "Running transaction: $tx");
    my $ok = $self->execute_yum_command([YUM_CMD], "running transaction", 1,
                                        $tx, $tx_error_is_warn ? "warn" : "error");
    return defined($ok);
}

# Prepares two sets of stuff to versionlock, from the escaped
# structure in $pkgs.  Returns a set with the package names that need
# to be versionlocked, and a reference to a list to be passed to
# repoquery.
#
# The set has the * globs removed from the package names, to fix issue
# #100.  It doesn't remove them from the versions, so that we can
# still lock stuff like "any available python 2.7 (but not the
# 2.4.x!!)
sub prepare_lock_lists
{
    my ($self, $pkgs) = @_;

    my $locked = Set::Scalar->new();

    my $toquery = [];

    while (my ($pkg, $ver) = each(%$pkgs)) {
        my $name = unescape($pkg);
        my $gn = $name;
        $gn =~ s{\*}{}g;
        while (my ($v, $a) = each(%$ver)) {
            my $version = unescape($v);
            next if $version eq '*';
            foreach my $arch (keys(%{$a->{arch}})) {
                $locked->insert("$gn-$version.$arch");
                push(@$toquery, "$name-$version.$arch");
            }
        }
    }

    return ($locked, $toquery);
}

# generate a msg for logging purposes based on
# wanted_locked and not_matched (passed as ref here)
# The message can be long because it contains list of
# all packages and non-exact matched repoquery output
# Lists are not comma separated so it can be copied
# and used on command line
sub _make_msg_wanted_locked
{

    my ($wanted_locked, $not_matched_ref) = @_;

    return sprintf(
        "%d wanted packages with wildcards: %s, ".
        "%d non-exact matched packages from repoquery: %s",
        $wanted_locked->size, join(" ", @$wanted_locked),
        scalar @$not_matched_ref, join(" ", @$not_matched_ref)
        );

}

# Returns whether the $locked string locks all the items in
# $wanted_locked.  Warning: $wanted_locked will be modified!!
# ($locked is output from REPOQUERY).
# When C<fullsearch> is true, the result will be checked
# for with glob pattern matching to verify the requested packages
# are in the $locked string. Otherwise, any requested package with
# a wildcard will be assumed to have a match in the output.
# The main issue with fullsearch is that it is a possibly slow process.
sub locked_all_packages
{
    my ($self, $wanted_locked, $locked, $fullsearch) = @_;

    my @not_matched;

    # Process output and filter exact matches
    foreach my $pkgstr (split(/\n/, $locked)) {
        my @envra = split(/:/, $pkgstr);
        my $pkg = $envra[1];
        if ($wanted_locked->has($pkg)) {
            $wanted_locked->delete($pkg);
        } else {
            # keep repoquery output of non-exact matched packages
            # locked packages like kernel*-some.version will cause other
            # entries like kernel-devel in the repoquery output, which
            # will never match, so having packages in @not_locked.
            push(@not_matched, $pkg) if $pkg;
        }
    }

    # No wanted_locked packages left, everything matched
    if (! @$wanted_locked) {
        $self->verbose("All wanted_locked packages found (without any wildcard processing).");
        return 1;
    }

    my $msg = _make_msg_wanted_locked($wanted_locked, \@not_matched);
    if ($fullsearch) {
        # At this point, all remaining entries in the wanted_locked
        # might have a wildcard in them.
        # Brute-force could possibly lead to a very slow worst case scenario
        #
        # Issue: single wildcard might match multiple lines of output,
        #   so always process all output
        $self->verbose("Starting fullsearch on $msg.");
        foreach my $wl (@$wanted_locked) {
            # (try to) match @not_matched
            # TODO: remove the matches? can we assume that every
            #  match corresponds to exactly one wildcard? probably not.
            #  e.g. a-*5 will match a-6.5, but also a-devel-6.5; so a-devel-*5
            #  would be left without (valid) match.
            #  -> current implementation does not remove the matches.
            $wanted_locked->delete($wl) if (grep(match_glob($wl, $_), @not_matched));
        }

        $msg = "wanted_locked packages found (with fullsearch wildcard processing)." .
            "Finished fullsearch with " .
            _make_msg_wanted_locked($wanted_locked, \@not_matched);
        if (@$wanted_locked) {
            $self->error("Not all $msg.");
            return 0;
        } else {
            $self->verbose("All $msg.");
            return 1;
        }
    } elsif (grep($_ !~ m{[*?]}, @$wanted_locked)) {
        $self->error("Unable to lock all packages. ",
                     "These packages with these versions don't seem to exist ",
                     "in any configured repositories. $msg.");
        return 0;
    } elsif (grep($_ =~ m{[*?]}, @$wanted_locked)) {
        # actually, only wildcards in the versions
        $self->info("Unsure if all wanted packages are avaialble ",
                    "due to wildcard(s) in the names and/or versions, ",
                    "continuing as if all is fine. ",
                    "Turn on fullsearch option to resolve the wildcards ",
                    "(but be aware of potential speed impact: $msg).");
        return 1;
    }

    # how do we get here?
    return 1;
}

# Lock the versions of any packages that have them
sub versionlock
{
    my ($self, $pkgs, $fullsearch) = @_;

    my ($locked, $toquery) = $self->prepare_lock_lists($pkgs);
    my $out = $self->execute_yum_command([REPOQUERY, @$toquery],
                                         "determining epochs", 1);
    return 0 if !defined($out) || !$self->locked_all_packages($locked, $out, $fullsearch);


    my $fh = CAF::FileWriter->new(YUM_PACKAGE_LIST, log => $self);
    print $fh "$out\n";
    $fh->close();
    return 1;
}

# Returns the set of packages to remove. A package must be removed if
# it is a leaf package and is not listed in $wanted, or if its
# architecture doesn't match the architectures specified in $wanted
# for that package.
sub packages_to_remove
{
    my ($self, $wanted) = @_;

    my $out = CAF::Process->new(LEAF_PACKAGES, keeps_state => 1,
                                log => $self)->output();

    if ($?) {
        $self->error ("Unable to find leaf packages");
        return;
    }

    # The leaf set doesn't contain the header lines, which are just
    # garbage.
    my $leaves = Set::Scalar->new(grep($_ !~ m{\s}, split(/\n/, $out)));

    my $candidates = $leaves-$wanted;

    my $false_positives = Set::Scalar->new();
    foreach my $pkg (@$candidates) {
        my $name = (split(/;/, $pkg))[0];
        if ($wanted->has($name)) {
            $false_positives->insert($pkg);
        }
    }

    return $candidates-$false_positives;
}

# Queries for packages packages that depend on $rm, and if there is a
# match in $install, it removes the $rm entry.
sub spare_deps_whatreq
{
    my ($self, $rm, $install) = @_;

    my @to_rm;

    foreach my $pk (@$rm) {
        my $arg = $pk;
        $arg =~ s{;}{.};
        my $whatreqs = $self->execute_yum_command([REPO_WHATREQS, $arg],
                              "determine what requires $pk", 1);
        return 0 if !defined($whatreqs);
        foreach my $wr (split("\n", $whatreqs)) {
            if ($install->has($wr)) {
                push(@to_rm, $pk);
            }
        }
    }

    $rm->delete(@to_rm);
    return 1;
}


# Queries for all the dependencies of the packages in $install and
# removes them from $rm.
sub spare_deps_requires
{
    my ($self, $rm, $install) = @_;

    my (@pkgs);

    foreach my $pkg (@$install) {
        $pkg =~ s{;}{.};
        push(@pkgs, $pkg);
    }

    my $deps = $self->execute_yum_command([REPO_DEPS, @pkgs],
                      "dependencies of install candidates", 1);

    return 0 if !defined $deps;

    foreach my $dep (split("\n", $deps)) {
       $rm->delete($dep);
    }

    return 1;
}

# Removes from $rm any packages that are depended on by any of the
# packages in $install.
#
# If any package in $install depended on anything in $rm we'd
# get a conflict when running the transaction.  We ensure this won't
# happen.
#
# It needs to call repoquery, and on large transactions that may be
# slow.  That's why we try to optimise the easy case where there is
# almost nothing to remove and a lot of new things to add.
sub spare_dependencies
{
    my ($self, $rm, $install) = @_;

    return 1 if (!$rm || !$install);

    # The whatreq path seems to have *cubic* cost!! It's still a big
    # speedup for installations, where we want to remove almost
    # nothing and may want to install and upgrade quite a lot of
    # things.
    if (scalar(@$rm) < SMALL_REMOVAL && scalar(@$install) > LARGE_INSTALL) {
        $self->debug(3, "Sparing dependencies in the whatreq path");
        return $self->spare_deps_whatreq($rm, $install);
    } else {
        $self->debug(3, "Sparing dependencies in the requires path");
        return $self->spare_deps_requires($rm, $install);
    }
}


# Completes any pending transactions
sub complete_transaction
{
    my ($self) = @_;

    return defined($self->execute_yum_command([YUM_COMPLETE_TRANSACTION],
                                              "complete previous transactions"));
}

# Purges the Yum repository caches.  For now we only care about the
# metadata, in order to avoid re-downloading re-installed packages.
sub purge_yum_caches
{
    my ($self) = @_;

    return defined($self->execute_yum_command([YUM_PURGE_METADATA],
                                              "purge repository metadata"));
}

# Runs yum distro-sync.  Before modifying the installed sets we must
# align the system to the repositories.  Otherwise we'll get a lot of problems.
sub distrosync
{
    my ($self, $run) = @_;

    if (!$run) {
        $self->info("Skipping yum distro-sync");
        return 1;
    }

    return $self->execute_yum_command([YUM_DISTRO_SYNC], "synchronisation with upstream");
}

# Updates the packages on the system.
sub update_pkgs
{
    my ($self, $pkgs, $groups, $run, $allow_user_pkgs, $purge, $tx_error_is_warn, $fullsearch) = @_;

    $self->complete_transaction() or return 0;

    if ($purge) {
        $self->purge_yum_caches() or return 0;
    } else {
        $self->expire_yum_caches() or return 0;
    }

    $self->versionlock($pkgs, $fullsearch) or return 0;

    $self->distrosync($run) or return 0;

    my $group_pkgs = $self->expand_groups($groups);
    defined($group_pkgs) or return 0;

    my $wanted_pkgs = $self->wanted_pkgs($pkgs);
    defined($wanted_pkgs) or return 0;

    my $wanted = $group_pkgs + $wanted_pkgs;

    my $installed = $self->installed_pkgs();
    defined($installed) or return 0;

    my ($tx, $to_rm, $to_install);

    $to_install = $wanted-$installed;

    if (!$allow_user_pkgs) {
        $to_rm = $self->packages_to_remove($wanted);
        defined($to_rm) or return 0;
        $self->spare_dependencies($to_rm, $to_install);
        $tx = $self->schedule(REMOVE, $to_rm);
    }

    $tx .= $self->schedule(INSTALL, $to_install);

    if ($tx) {
        $tx .= $self->solve_transaction($run);
        $self->apply_transaction($tx, $tx_error_is_warn) or return 0;
    }

    return 1;
}

# Updates the packages on the system.
sub update_pkgs_retry
{
    my ($self, $pkgs, $groups, $run, $allow_user_pkgs, $purge, $retry_if_not_allow_user_pkgs, $fullsearch) = @_;

    # If an error is logged due to failed transaction,
    # it might be retried and might succeed, but ncm-ncd will not allow
    # any component that has spma as dependency (i.e. typically all others)
    # to run (becasue he initial attempt had an error)
    my $tx_error_is_warn = $retry_if_not_allow_user_pkgs && ! $allow_user_pkgs;

    # Introduce shortcut to call update_pkgs with the same except 2 arguments
    my $update_pkgs = sub {
        my ($allow_user_pkgs, $tx_error_is_warn) = @_;
        return $self->update_pkgs($pkgs, $groups, $run, $allow_user_pkgs,
                                  $purge, $tx_error_is_warn, $fullsearch);
    };

    if(&$update_pkgs($allow_user_pkgs, $tx_error_is_warn)) {
        $self->verbose("update_pkgs ok");
    } else {
        if ($allow_user_pkgs) {
            # tx_error_is_warn = 0 in this case, error is already logged
            $self->verbose("update_pkgs failed, userpkgs=true");
            return 0;
        } elsif ($retry_if_not_allow_user_pkgs) {
            # all tx failures are errors here
            $tx_error_is_warn = 0;

            $self->verbose("userpkgs_retry: 1st update_pkgs failed, going to retry with forced userpkgs=true");
            $allow_user_pkgs = 1;
            if(&$update_pkgs($allow_user_pkgs, $tx_error_is_warn)) {
                $self->verbose("userpkgs_retry: 2nd update_pkgs with forced userpkgs=true ok, trying 3rd");
                $allow_user_pkgs = 0;
                if(&$update_pkgs($allow_user_pkgs, $tx_error_is_warn)) {
                    $self->verbose("userpkgs_retry: 3rd update_pkgs with userpkgs=false ok.");
                } else {
                    $self->error("userpkgs_retry: 3rd update_pkgs with userpkgs=false failed.");
                    return 0;
                };
            } else {
                $self->error("userpkgs_retry: 2nd update_pkgs with forced userpkgs=true failed.");
                return 0;
            };
        } else {
            # log failure, no retry enabled
            # tx_error_is_warn = 0 in this case, error is already logged
            $self->verbose("update_pkgs failed, userpkgs=false, no retry enabled");
            return 0;
        }
    }

    return 1;
};


# Set up a few things about Yum.conf. Somewhere in the future this may
# have its own schema, or be delegated to some other component. To be
# seen.
sub configure_yum
{
    my ($self, $cfgfile, $obsolete) = @_;
    my $fh = CAF::FileEditor->new($cfgfile, log => $self);

    $fh->add_or_replace_lines(CLEANUP_ON_REMOVE,
                  CLEANUP_ON_REMOVE. q{\s*=\s*1},
                  "\n" . CLEANUP_ON_REMOVE . "=1\n", ENDING_OF_FILE);
    $fh->add_or_replace_lines(OBSOLETE,
                  OBSOLETE . "\\s*=\\s*$obsolete",
                  "\n".  OBSOLETE. "=$obsolete\n", ENDING_OF_FILE);
    $fh->close();
}

# Configure the yum plugins
sub configure_plugins
{
    my ($self, $plugins) = @_;

    # Sanity checks
    # versionlock plugin: enable by default
    if ($plugins->{versionlock}) {
        # TODO: check and warn for disabled versionlock plugin?
        # versionlock plugin: locklist is mandatory in schema
        if ($plugins->{versionlock}->{locklist} ne YUM_PACKAGE_LIST) {
            $self->warn("yum plugin versionlock plugin unsupported locklist $plugins->{versionlock}->{locklist}. ",
                        "Forcing it to ".YUM_PACKAGE_LIST.".");
            $plugins->{versionlock}->{locklist} = YUM_PACKAGE_LIST;
        }
    } else {
        $self->verbose("yum plugin versionlock is not configured. Will be enabled.");
        $plugins->{versionlock} = {
            enabled => 1,
            locklist => YUM_PACKAGE_LIST,
        };
    }

    # fastestmirror plugin: disable by default
    if (! $plugins->{fastestmirror}) {
        $self->verbose("yum plugin fastestmirror is not configured. It will be disabled.");
        $plugins->{fastestmirror}->{enabled} = 0;
    }

    my $changes = 0;
    foreach my $plugin (sort keys %$plugins) {
        $self->verbose("Going to configure plugin $plugin.");
        my $trd = EDG::WP4::CCM::TextRender->new(
            "yumplugins/$plugin",
            $plugins->{$plugin},
            relpath => 'spma',
            log => $self);

        # returns undef on render error, the error is logged
        my $fh = $trd->filewriter(YUM_PLUGIN_DIR . "/$plugin.conf");

        if(defined $fh) {
            $changes += $fh->close() || 0; # handle undef
        }
    }

    return $changes;
}

sub Configure
{
    my ($self, $config) = @_;

    # We are parsing some outputs in this component.  We must set a
    # locale that we can understand.
    local $ENV{LANG} = 'C';
    local $ENV{LC_ALL} = 'C';

    my $purge_caches;
    my $repos = $config->getElement(REPOS_TREE)->getTree();
    my $t = $config->getElement(CMP_TREE)->getTree();
    # Convert these crappily-defined fields into real Perl booleans.
    $t->{run} = $t->{run} eq 'yes';
    $t->{userpkgs} = defined($t->{userpkgs}) && $t->{userpkgs} eq 'yes';
    my $pkgs = $config->getElement(PKGS_TREE)->getTree();
    my $groups;
    if ($config->elementExists(GROUPS_TREE)) {
        $groups = $config->getElement(GROUPS_TREE)->getTree();
    } else {
        $groups = {};
    }

    # TODO: is this fatal or not?
    # TODO: should this also influence purge_caches?
    #       (if it does, the "defined($purge_caches) or return 0;" test has to be modified)
    # always run it, even if no plugins configured (e.g. to disable fastest mirror)
    $self->configure_plugins($t->{plugins});

    $self->initialize_repos_dir(REPOS_DIR) or return 0;
    $self->cleanup_old_repos(REPOS_DIR, $repos, $t->{userpkgs}) or return 0;
    $purge_caches = $self->generate_repos(REPOS_DIR, $repos, REPOS_TEMPLATE,
                                          $t->{proxyhost}, $t->{proxytype},
                                          $t->{proxyport});
    defined($purge_caches) or return 0;
    $self->configure_yum(YUM_CONF_FILE, $t->{process_obsoletes});

    $self->update_pkgs_retry($pkgs, $groups, $t->{run},
                             $t->{userpkgs}, $purge_caches, $t->{userpkgs_retry},
                             $t->{fullsearch})
        or return 0;
    return 1;
}

1; # required for Perl modules
