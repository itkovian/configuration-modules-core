# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}


# This component needs a 'ceph' user. 
# The user should be able to run these commands with sudo without password:
# /usr/bin/ceph-deploy
# /usr/bin/python -c import sys;exec(eval(sys.stdin.readline()))
# /usr/bin/python -u -c import sys;exec(eval(sys.stdin.readline()))
# /bin/mkdir
#

package NCM::Component::Ceph::daemon;

use 5.10.1;
use strict;
use warnings;

no if $] >= 5.017011, warnings => 'experimental::smartmatch';

use LC::Exception;
use LC::Find;

use Data::Dumper;
use EDG::WP4::CCM::Element qw(unescape);
use File::Basename;
use File::Copy qw(copy move);
use JSON::XS;
use Readonly;
use Socket;
use Sys::Hostname;
our $EC=LC::Exception::Context->new->will_store_all;
Readonly my $OSDBASE => qw(/var/lib/ceph/osd/);
Readonly my $JOURNALBASE => qw(/var/lib/ceph/log/);

# get host of ip; save the map to avoid repetition
sub get_host {
    my ($self, $ip, $hostmap) = @_;
    if (!$hostmap->{$ip}) {
        $hostmap->{$ip} = gethostbyaddr(Socket::inet_aton($ip), Socket::AF_INET());
        $self->debug(3, "host of $ip is $hostmap->{$ip}");
    }
    return $hostmap->{$ip};
}
    
# Gets the OSD map
sub osd_hash {
    my ($self, $master, $mapping) = @_; 
    my $jstr = $self->run_ceph_command([qw(osd dump)]) or return 0;
    my $osddump = decode_json($jstr);  
    my %osdparsed = ();
    my $hostmap = {};
    foreach my $osd (@{$osddump->{osds}}) {
        my $id = $osd->{osd};
        my ($name,$host);
        $name = "osd.$id";
        my @addr = split(':', $osd->{public_addr});
        my $ip = $addr[0];
        if (!$ip) {
            $self->error("IP of osd osd.$id not set or misconfigured!");
            return 0;
        }
        my $fqdn = $self->get_host($ip, $hostmap);
        if (!$fqdn) {
            $self->error("Parsing osd commands went wrong: Could not retrieve fqdn of ip $ip.");
            return 0;
        }
        
        my @fhost = split('\.', $fqdn);
        $host = $fhost[0];
        
        # If host is unreachable, go on with empty one. Process this later 
        if (!defined($master->{$host}->{fault})) {
            if (!$self->test_host_connection($fqdn)) {
                $master->{$host}->{fault} = 1;
                $self->warn("Could not retrieve necessary information from host $host");
            } else {
                $master->{$host}->{fault} = 0;
            }
        } 
        next if $master->{$host}->{fault};
            
        my ($osdloc, $journalloc) = $self->get_osd_location($id, $fqdn, $osd->{uuid}) or return 0;
        
        my $osdp = { 
            name            => $name, 
            host            => $host, 
            ip              => $ip, 
            id              => $id, 
            uuid            => $osd->{uuid}, 
            up              => $osd->{up}, 
            in              => $osd->{in}, 
            osd_path        => $osdloc, 
            journal_path    => $journalloc 
        };
        my $osdstr = "$host:$osdloc";
        $osdparsed{$osdstr} = $osdp;
        $mapping->{get_loc}->{$id} = $osdstr;
        $mapping->{get_id}->{$host}->{$osdloc} = $id;
        $master->{$host}->{osds}->{osdstr} = $osdp;
    }
    return \%osdparsed; #FIXME? 
}

# checks whoami,fsid and ceph_fsid and returns the real path
sub get_osd_location {
    my ($self,$osd, $host, $uuid) = @_;
    my $osdlink = "/var/lib/ceph/osd/$self->{clname}-$osd";
    if (!$host) {
        $self->error("Can not find osd without a hostname");
        return ;
    }   
    
    my @catcmd = ('/usr/bin/cat');
    my $ph_uuid = $self->run_command_as_ceph_with_ssh([@catcmd, $osdlink . '/fsid'], $host);
    chomp($ph_uuid);
    if ($uuid ne $ph_uuid) {
        $self->error("UUID for osd.$osd of ceph command output differs from that on the disk. ",
            "Ceph value: $uuid, ", 
            "Disk value: $ph_uuid");
        return ;    
    }
    my $ph_fsid = $self->run_command_as_ceph_with_ssh([@catcmd, $osdlink . '/ceph_fsid'], $host);
    chomp($ph_fsid);
    my $fsid = $self->{fsid};
    if ($ph_fsid ne $fsid) {
        $self->error("fsid for osd.$osd not matching with this cluster! ", 
            "Cluster value: $fsid, ", 
            "Disk value: $ph_fsid");
        return ;
    }
    my @loccmd = ('/bin/readlink');
    my $osdloc = $self->run_command_as_ceph_with_ssh([@loccmd, $osdlink], $host);
    my $journalloc = $self->run_command_as_ceph_with_ssh([@loccmd, '-f', "$osdlink/journal"], $host);
    chomp($osdloc);
    chomp($journalloc);
    return $osdloc, $journalloc;

}

# If directory is given, checks if the directory is empty
# If raw device is given, check for existing file systems
sub check_empty {
    my ($self, $loc, $host) = @_;
    if ($loc =~ m{^/dev/}){
        my $cmd = ['sudo', '/usr/bin/file', '-s', $loc];
        my $output = $self->run_command_as_ceph_with_ssh($cmd, $host) or return 0;
        if ($output !~ m/^$loc\s*:\s+data\s*$/) { 
            $self->error("On host $host: $output", "Expected 'data'");
            return 0;
        }
    } else {
        my $mkdircmd = ['sudo', '/bin/mkdir', '-p', $loc];
        $self->run_command_as_ceph_with_ssh($mkdircmd, $host); 
        my $lscmd = ['/usr/bin/ls', '-1', $loc];
        my $lsoutput = $self->run_command_as_ceph_with_ssh($lscmd, $host) or return 0;
        my $lines = $lsoutput =~ tr/\n//;
        if ($lines) {
            $self->error("$loc on $host is not empty!");
            return 0;
        } 
    }
    return 1;    
}

# Gets the MON map
sub mon_hash {
    my ($self, $master) = @_;
    my $jstr = $self->run_ceph_command([qw(mon dump)]) or return 0;
    my $monsh = decode_json($jstr);
    $jstr = $self->run_ceph_command([qw(quorum_status)]) or return 0;
    my $monstate = decode_json($jstr);
    my %monparsed = ();
    foreach my $mon (@{$monsh->{mons}}){
        $mon->{up} = $mon->{name} ~~ @{$monstate->{quorum_names}};
        $monparsed{$mon->{name}} = $mon; 
        $master->{$mon->{name}}->{mon} = $mon; #One monitor per host
    }
    return \%monparsed;
}

# Gets the MDS map 
sub mds_hash {
    my ($self, $master) = @_;
    my $jstr = $self->run_ceph_command([qw(mds stat)]) or return 0;
    my $mdshs = decode_json($jstr);
    my %mdsparsed = ();
    foreach my $mds (values %{$mdshs->{mdsmap}->{info}}) {
        my @state = split(':', $mds->{state});
        my $up = ($state[0] eq 'up') ? 1 : 0 ;
        my $mdsp = {
            name => $mds->{name},
            gid => $mds->{gid},
            up => $up
        };
        $mdsparsed{$mds->{name}} = $mdsp;
        #FIXME: For daemons rolled out with old version of ncm-ceph
        my @fhost = split('\.', $mds->{name});
        my $host = $fhost[0];
        $master->{$host}->{mds} = $mdsp;
    }
    return \%mdsparsed;
}       

## Processing and comparing between Quattor and Ceph

# Do a comparison of quattor config and the actual ceph config 
# for a given type (cfg, mon, osd, mds)
sub ceph_quattor_cmp {#MFD
    my ($self, $type, $quath, $cephh, $cmdh) = @_;
    foreach my $qkey (sort(keys %{$quath})) {
        if (exists $cephh->{$qkey}) {
            my $pair = [$quath->{$qkey}, $cephh->{$qkey}];
            #check attrs and reconfigure
            $self->config_daemon($type, 'change', $qkey, $pair, $cmdh) or return 0;
            delete $cephh->{$qkey};
        } else {
            $self->config_daemon($type, 'add', $qkey, $quath->{$qkey}, $cmdh) or return 0;
        }
    }
    foreach my $ckey (keys %{$cephh}) {
        $self->config_daemon($type, 'del', $ckey, $cephh->{$ckey}, $cmdh) or return 0;
    }        
    return 1;
}

# Compare ceph mons with the quattor mons
sub process_mons {#MFD
    my ($self, $qmons, $cmdh) = @_;
    my $cmons = $self->mon_hash() or return 0;
    return $self->ceph_quattor_cmp('mon', $qmons, $cmons, $cmdh);
}

# Converts a host/osd hierarchy in a 'host:osd' structure
sub flatten_osds {#MFO
    my ($self, $hosds) = @_; 
    my %flat = ();
    while (my ($hostname, $host) = each(%{$hosds})) {
        my $osds = $host->{osds};
        while (my ($osdpath, $newosd) = each(%{$osds})) {
            $newosd->{host} = $hostname;
            $newosd->{fqdn} = $host->{fqdn};
            $osdpath = unescape($osdpath);
            if ($osdpath !~ m|^/|){
                $osdpath = $OSDBASE . $osdpath;
            }
            if (exists($newosd->{journal_path}) && $newosd->{journal_path} !~ m|^/|){
                $newosd->{journal_path} = $JOURNALBASE . $newosd->{journal_path};
            }
            $newosd->{osd_path} = $osdpath;
            my $osdstr = "$hostname:$osdpath" ;
            $flat{$osdstr} = $newosd;
        }
    }
    return \%flat;
}


#NEW FIXME:
# Like flatten_osd, but for single host.. 
sub structure_osds {
    my ($self, $hostname, $host) = @_; 
    my $osds = $host->{osds};
    my %flat = (); 
    while (my ($osdpath, $newosd) = each(%{$osds})) {
        $newosd->{host} = $hostname;
        $newosd->{fqdn} = $host->{fqdn};
        $osdpath = unescape($osdpath);
        if ($osdpath !~ m|^/|){
            $osdpath = $OSDBASE . $osdpath;
        }
        if (exists($newosd->{journal_path}) && $newosd->{journal_path} !~ m|^/|){
            $newosd->{journal_path} = $JOURNALBASE . $newosd->{journal_path};
        }
        $newosd->{osd_path} = $osdpath;
        my $osdstr = "$hostname:$osdpath";
        $flat{$osdstr} = $newosd;
    }   
    return \%flat;

}

# Compare cephs osd with the quattor osds
sub process_osds {#MFD
    my ($self, $qosds, $cmdh) = @_;
    my $qflosds = $self->flatten_osds($qosds);
    $self->debug(5, 'OSD lay-out', Dumper($qosds));
    $self->info('Building osd information hash, this can take a while..');
    my $cosds = $self->osd_hash() or return 0;
    return $self->ceph_quattor_cmp('osd', $qflosds, $cosds, $cmdh);
}

# Compare cephs mds with the quattor mds
sub process_mdss {#MFD
    my ($self, $qmdss, $cmdh) = @_;
    my $cmdss = $self->mds_hash() or return 0;
    return $self->ceph_quattor_cmp('mds', $qmdss, $cmdss, $cmdh);
}

# Prepare the commands to change/add/delete a monitor  
sub config_mon {#MFD
    my ($self,$action,$name,$daemonh, $cmdh) = @_;
    if ($action eq 'add'){
        my @command = qw(mon create);
        push (@command, $daemonh->{fqdn});
        push (@{$cmdh->{deploy_cmds}}, [@command]);
    } elsif ($action eq 'del') {
        my @command = qw(mon destroy);
        push (@command, $name);
        push (@{$cmdh->{man_cmds}}, [@command]);
    } elsif ($action eq 'change') { #compare config
        my $quatmon = $daemonh->[0];
        my $cephmon = $daemonh->[1];
        # checking immutable attributes
        my @monattrs = ();
        $self->check_immutables($name, \@monattrs, $quatmon, $cephmon) or return 0;
        
        if ($cephmon->{addr} =~ /^0\.0\.0\.0:0/) { #Initial (unconfigured) member
               $self->config_mon('add', $name, $quatmon, $cmdh);
        }
        $self->check_state($name, $name, 'mon', $quatmon, $cephmon, $cmdh);
        
        my $donecmd = ['test','-e',"/var/lib/ceph/mon/$self->{clname}-$name/done"];
        if (!$cephmon->{up} && !$self->run_command_as_ceph_with_ssh($donecmd, $quatmon->{fqdn})) {
            # Node reinstalled without first destroying it
            $self->info("Monitor $name shall be reinstalled");
            return $self->config_mon('add',$name,$quatmon, $cmdh);
        }
    }
    else {
        $self->error("Action $action not supported!");
        return 0;
    }
    return 1;   
}

#does a check on unchangable attributes, returns 0 if different
sub check_immutables {
    my ($self, $name, $imm, $quat, $ceph) = @_;
    my $rc =1;
    foreach my $attr (@{$imm}) {
        if ((defined($quat->{$attr}) || defined($ceph->{$attr})) && 
            ($quat->{$attr} ne $ceph->{$attr}) ){
            $self->error("Attribute $attr of $name not corresponding.", 
                "Quattor: $quat->{$attr}, ",
                "Ceph: $ceph->{$attr}");
            $rc=0;
        }
    }
    return $rc;
}
# Checks and changes the state on the host
sub check_state {#TODO MFC
    my ($self, $id, $host, $type, $quat, $ceph, $cmdh) = @_;
    if (($host eq $self->{hostname}) and ($quat->{up} xor $ceph->{up})){
        my @command; 
        if ($quat->{up}) {
            @command = qw(start); 
        } else {
            @command = qw(stop);
        }
        push (@command, "$type.$id");
        push (@{$cmdh->{daemon_cmds}}, [@command]);
    }
}

sub prep_osd { #NEW
    my ($self,$osd) = @_;
    
    $self->check_empty($osd->{osd_path}, $osd->{fqdn}) or return 0;
    if ($osd->{journal_path}) {
        (my $journaldir = $osd->{journal_path}) =~ s{/journal$}{};
        $self->check_empty($journaldir, $osd->{fqdn}) or return 0;
    }
}

# Prepare the commands to change/add/delete an osd
sub config_osd {#FIXME #MFD
    my ($self,$action,$name,$daemonh, $cmdh) = @_;
    if ($action eq 'add'){
        #TODO: change to 'create' ?
        $self->check_empty($daemonh->{osd_path}, $daemonh->{fqdn}) or return 0;
        $self->debug(2,"Adding osd $name");
        my $prepcmd = [qw(osd prepare)];
        my $activcmd = [qw(osd activate)];
        my $pathstring = "$daemonh->{fqdn}:$daemonh->{osd_path}";
        if ($daemonh->{journal_path}) {
            (my $journaldir = $daemonh->{journal_path}) =~ s{/journal$}{};
            $self->check_empty($journaldir, $daemonh->{fqdn}) or return 0; 
            $pathstring = "$pathstring:$daemonh->{journal_path}";
        }
        for my $command (($prepcmd, $activcmd)) {
            push (@$command, $pathstring);
            push (@{$cmdh->{deploy_cmds}}, $command);
        }
    } elsif ($action eq 'del') {
        my @command = qw(osd destroy);
        push (@command, $daemonh->{name});
        push (@{$cmdh->{man_cmds}}, [@command]);
   
    } elsif ($action eq 'change') { #compare config
        my $quatosd = $daemonh->[0];
        my $cephosd = $daemonh->[1];
        # checking immutable attributes
        my @osdattrs = ('host', 'osd_path');
        if ($quatosd->{journal_path}) {
            push(@osdattrs, 'journal_path');
        }
        $self->check_immutables($name, \@osdattrs, $quatosd, $cephosd) or return 0;
        (my $id = $cephosd->{id}) =~ s/^osd\.//;
        $self->check_state($id, $quatosd->{host}, 'osd', $quatosd, $cephosd, $cmdh);
        #TODO: Make it possible to bring osd 'in' or 'out' the cluster ?
    } else {
        $self->error("Action $action not supported!");
        return 0;
    }
    return 1;
}

sub prep_mds { #NEW
    my ($self, $hostname, $mds) = @_;
        my $fqdn = $mds->{fqdn};
        my $donecmd = ['test','-e',"/var/lib/ceph/mds/$self->{clname}-$hostname/done"];
        return $self->run_command_as_ceph_with_ssh($donecmd, $fqdn);
}

# Prepare the commands to change/add/delete an mds
sub config_mds {
    my ($self,$action,$name,$daemonh, $cmdh) = @_;
    if ($action eq 'add'){
        my $fqdn = $daemonh->{fqdn};
        my $donecmd = ['test','-e',"/var/lib/ceph/mds/$self->{clname}-$name/done"];
        my $mds_exists = $self->run_command_as_ceph_with_ssh($donecmd, $fqdn);
        if ($mds_exists) { # Ceph does not show a down ceph mds daemon in his mds map
            if ($daemonh->{up} && ($name eq $self->{hostname})) {
                my @command = ('start', "mds.$name");
                push (@{$cmdh->{daemon_cmds}}, [@command]);
            }
        } else {
            my @command = qw(mds create);
            push (@command, $fqdn);
            push (@{$cmdh->{deploy_cmds}}, [@command]);
        }   
    } elsif ($action eq 'del') {
        my @command = qw(mds destroy);
        push (@command, $name);
        push (@{$cmdh->{man_cmds}}, [@command]);
    
    } elsif ($action eq 'change') {
        my $quatmds = $daemonh->[0];
        my $cephmds = $daemonh->[1];
        # Note: A down ceph mds daemon is not in map
        $self->check_state($name, $name, 'mds', $quatmds, $cephmds, $cmdh);
    } else {
        $self->error("Action $action not supported!");
        return 0;
    }
    return 1;
}


# Configure on a type basis
sub config_daemon {
    my ($self, $type,$action,$name,$daemonh, $cmdh) = @_;
    if ($type eq 'mon'){
        return $self->config_mon($action,$name,$daemonh, $cmdh);
    }
    elsif ($type eq 'osd'){
        return $self->config_osd($action,$name,$daemonh, $cmdh);
    }
    elsif ($type eq 'mds'){
        return $self->config_mds($action,$name,$daemonh, $cmdh);
    } 
    else {
        $self->error("No such type: $type");
        return 0;
    }
}

# Deploy daemons 
sub do_deploy {
    my ($self, $is_deploy, $cmdh) = @_;
    if ($is_deploy){ #Run only on deploy host(s)
        $self->info("Running ceph-deploy commands. This can take some time when adding new daemons. ");
        while (my $cmd = shift @{$cmdh->{deploy_cmds}}) {
            $self->debug(1, 'Running deploy command: ',@$cmd);
            $self->run_ceph_deploy_command($cmd) or return 0;
        }
    } else {
        $self->info("host is no deployhost, skipping ceph-deploy commands.");
        $cmdh->{deploy_cmds} = [];
    }
    while (my $cmd = shift @{$cmdh->{ceph_cmds}}) {
        $self->run_ceph_command($cmd) or return 0;
    }
    while (my $cmd = shift @{$cmdh->{daemon_cmds}}) {
        $self->debug(1,"Daemon command:", @$cmd);
        $self->run_daemon_command($cmd) or return 0;
    }
    $self->print_cmds($cmdh->{man_cmds});
    return 1;
}

#Initialize array buckets
sub init_commands {#FIXME #NEW
    my ($self) = @_;
    my $cmdh = {};
    $cmdh->{deploy_cmds} = [];
    $cmdh->{ceph_cmds} = [];
    $cmdh->{daemon_cmds} = [];
    $cmdh->{man_cmds} = [];
    return $cmdh;
}

# Compare the configuration (and prepare commands) 
sub check_daemon_configuration {
    my ($self, $cluster, $cmdh) = @_;
    $self->process_mons($cluster->{monitors}, $cmdh) or return 0;
    $self->process_osds($cluster->{osdhosts}, $cmdh) or return 0;
    $self->process_mdss($cluster->{mdss}, $cmdh) or return 0;
}

# Does the configuration and deployment of daemons
sub do_daemon_actions {
    my ($self, $cluster, $gvalues) = @_;
    my $is_deploy = $gvalues->{is_deploy};
    if ($is_deploy){
        $self->{clname} = $gvalues->{clname};
        $self->{fsid} = $cluster->{config}->{fsid};
        $self->{hostname} = $gvalues->{hostname};
        my $cmdh = $self->init_commands();
        $self->check_daemon_configuration($cluster, $cmdh) or return 0;
        $self->debug(1,"deploying commands");    
        return $self->do_deploy($is_deploy, $cmdh);
    }
    return 1;
}

1; # Required for perl module!
