use strict;
use warnings;
use File::Temp;
use Test::More tests => 4;
use File::Path qw(mkpath);
use File::Spec;
use IPC::ConcurrencyLimit::WithStandby;

# TMPDIR will hopefully put it in the logical equivalent of
# a /tmp. That is important because no sane admin will mount /tmp
# via NFS and we don't want to fail tests just because we're being
# built/tested on an NFS share.
my $tmpdir = File::Temp::tempdir( CLEANUP => 1, TMPDIR => 1 );
my $standby = File::Spec->catdir($tmpdir, 'standby');
mkpath($standby);

my %shared_opt = (
  path => $tmpdir,
  standby_path => $standby,
  max_procs => 1,
  lock_mode => 'exclusive',
  interval => 0.5,
  retries => 10,
);

SCOPE: {
  my $limit = IPC::ConcurrencyLimit::WithStandby->new(%shared_opt);
  isa_ok($limit, 'IPC::ConcurrencyLimit::WithStandby');

  my $id = $limit->get_lock;
  ok($id, 'Got lock');

  my $limit2 = IPC::ConcurrencyLimit::WithStandby->new(%shared_opt);
  my $idr;
  SCOPE: {
    local $limit2->{interval} = 0;
    $idr = $limit2->get_lock;
    ok(not defined $idr);
  }

  my $pid = fork();
  if ($pid) {
    $limit->release_lock;
    $idr = $limit2->get_lock;
    ok(defined $idr);
  }
  else {
    sleep 2;
    $limit->release_lock;
    exit;
  }
  waitpid($pid, 0);
}

File::Path::rmtree($tmpdir);
