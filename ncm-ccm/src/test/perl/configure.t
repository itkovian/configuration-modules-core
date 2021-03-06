# -* mode: cperl -*-
use strict;
use warnings;
use Test::More;
use Test::Quattor qw(base);
use NCM::Component::ccm;
use CAF::Object;
use Test::MockModule;
use CAF::FileWriter;


my $ccmconf = "/etc/ccm.conf";
my $mock = Test::MockModule->new("CAF::FileWriter");

$mock->mock("cancel", sub {
		my $self = shift;
		*$self->{CANCELLED}++;
		*$self->{save} = 0;
	    });

my $tmppath;
my $mock_ccm = Test::MockModule->new("NCM::Component::ccm");
$mock_ccm->mock('tempdir', sub { mkdir($tmppath); return $tmppath; });

$CAF::Object::NoAction = 1;

my $cmp = NCM::Component::ccm->new("ccm");

=pod

=head1 Tests for the CCM component

=cut

my $cfg = get_config_for_profile("base");

$tmppath = "target/ncm-ccm-test1";
$cmp->Configure($cfg);
ok(!exists($cmp->{ERROR}), "No errors found in normal execution");
my $fh = get_file($ccmconf);
isa_ok($fh, "CAF::FileWriter", "A file was opened");

like($fh, qr{(?:^\w+ [\w\-/\.]+$)+}m, "Lines are correctly printed");
unlike($fh, qr{^(?:version|config)}m, "Unwanted fields are removed");

my $tstcmd = get_command(join(" ", NCM::Component::ccm::TEST_COMMAND, "$tmppath/$ccmconf"));
isa_ok($tstcmd->{object}, 'CAF::Process', "Test command found");
my $tmpfh = get_file("$tmppath/$ccmconf");
isa_ok($tmpfh, "CAF::FileWriter", "A tmp file was opened");
is("$tmpfh", "$fh", "config and tmp files have same content");

$tmppath = "target/ncm-ccm-test2";
set_command_status(join(" ", NCM::Component::ccm::TEST_COMMAND, "$tmppath/$ccmconf"), 1);

is(scalar(grep(m{ccm-fetch|cfgfile}, NCM::Component::ccm::TEST_COMMAND)), 2,
   "Expected arguments passed to ccm-fetch");

$cmp->Configure($cfg);
is($cmp->{ERROR}, 1, "Failure in ccm-fetch is detected");
$fh = get_file("/etc/ccm.conf");
is(*$fh->{CANCELLED}, 2, "File contents are cancelled upon error");

done_testing();
