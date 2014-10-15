# # -*- mode: cperl -*-
# ${license-info}
# ${author-info}
# ${build-info}

=pod

=head1 DESCRIPTION

Test the Configure of the symlink component

=cut


use strict;
use warnings;
use Test::More;
use Test::Quattor qw(basic dupes);
use NCM::Component::symlink;
use CAF::Object;
use Readonly;

use Test::MockModule;

our $links = {};
my $mock = Test::MockModule->new('NCM::Component::symlink');
$mock->mock('process_link', sub {
        my ($self, $link, $href) = @_;
        $links->{$link}=$href->{target}->getValue();
        return 1;
        });

$CAF::Object::NoAction = 1;

my $cfg;
my $cmp = NCM::Component::symlink->new('symlink');

$cfg = get_config_for_profile('basic');
is($cmp->Configure($cfg), 1, "Basic Configure returns 1");
is_deeply($links, {"/link1" => "target1", "/link2" => "target2"}, "process_link processed links");
ok(! defined($cmp->{ERROR}), "No error is reported");

$links = {};
$cfg = get_config_for_profile('dupes');
is($cmp->Configure($cfg), 1, "Dupes Configure returns 1");
# process last link1 with 
is_deeply($links, {"/link1" => "target1b", "/link2" => "target2"}, "process_link processed link dupes");
# check for logged error
is($cmp->{ERROR}, 1, "Error is reported");


done_testing();
