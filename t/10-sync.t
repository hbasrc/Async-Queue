
use strict;
use warnings;
use Test::More;

BEGIN {
    use_ok("Async::Queue");
}

{
    my @results = ();
    my $q = new_ok('Async::Queue', [ concurrency => 1, worker => sub {
        my ($task, $cb) = @_;
        push(@results, $task);
        $cb->(lc($task), uc($task));
    }]);
    is($q->length, 0, "length is 0 at first");
    is($q->running, 0, "running is 0 at first");
    $q->push("a");
    is($q->length, 0,  "synchronous task is immediately processed...");
    is($q->running, 0, "... thus length and running are always 0");
    is_deeply(\@results, ["a"], "results ok");
    @results = ();
    foreach my $letter (qw(b c d)) {
        $q->push($letter);
        is($q->length, 0, "length 0");
        is($q->running, 0, "running 0");
    }
    is_deeply(\@results, [qw(b c d)], "results OK");
    
    @results = ();
    $q->push("E", sub {
        my @args = @_;
        push(@results, @args);
    });
    is_deeply(\@results, [qw(E e E)], "results OK. push() callback is called with arguments");
}

## TODO: other callbacks
## TODO: async tests
## TODO: errors

done_testing();
