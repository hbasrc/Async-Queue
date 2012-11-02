package Async::Queue;

use 5.006;
use strict;
use warnings;

use Carp;

sub new {
    my ($class, %options) = @_;
    my $self = bless {
        concurrency => 1,
        worker => undef,
        drain => undef,
        empty => undef,
        saturated => undef,
        task_queue => [],
        running => 0,
    }, $class;
    $self->$_($options{$_}) foreach qw(concurrency worker drain empty saturated);
    return $self;
}

sub _define_hook_accessors {
    my ($name, %options) = @_;
    my $class = __PACKAGE__;
    my $fullname = "${class}::$name";
    no strict 'refs';
    *{$fullname} = sub {
        my ($self, $v) = @_;
        if(@_ > 1) {
            croak "$name must not be undef." if !defined($v) && !$options{allow_undef};
            croak "$name must be a coderef" if defined($v) && ref($v) ne 'CODE';
            croak "You canot set $name while there is a running task." if $self->running > 0;
            $self->{$name} = $v;
        }
        return $self->{$name};
    };
}

sub running {
    my ($self) = @_;
    return $self->{running};
}

sub concurrency {
    my ($self, $conc) = @_;
    if(defined($conc)) {
        croak "You cannot set concurrency while there is a running task" if $self->running > 0;
        $self->{concurrency} = int($conc);
    }
    return $self->{concurrency};
}

sub length {
    my ($self) = @_;
    return int(@{$self->{task_queue}});
}

_define_hook_accessors 'worker';
_define_hook_accessors $_, allow_undef => 1 foreach qw(drain empty saturated);

sub push {
    my ($self, $task, $cb) = @_;
    if(defined($cb) && ref($cb) ne 'CODE') {
        croak("callback for a task must be a coderef");
    }
    push(@{$self->{task_queue}}, [$task, $cb]);
    $self->_shift_run(1);
    return $self;
}

sub _shift_run {
    my ($self, $from_push) = @_;
    return if $self->concurrency > 0 && $self->running >= $self->concurrency;
    my $args_ref = shift(@{$self->{task_queue}});
    return if !defined($args_ref);
    my ($task, $cb) = @$args_ref;
    $self->{running} += 1;
    if($self->running == $self->concurrency && $from_push && defined($self->saturated)) {
        $self->saturated->($self);
    }
    if(@{$self->{task_queue}} == 0 && defined($self->empty)) {
        $self->empty->($self);
    }
    $self->worker->($task, sub {
        my (@worker_results) = @_;
        $cb->(@worker_results) if defined($cb);
        $self->{running} -= 1;
        if(@{$self->{task_queue}} == 0 && $self->running == 0 && defined($self->drain)) {
            $self->drain->($self);
        }
        @_ = ($self);
        goto &_shift_run;
    });
}


=head1 NAME

Async::Queue - The great new Async::Queue!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Async::Queue;

    my $foo = Async::Queue->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS


=head1 AUTHOR

Toshio Ito, C<< <debug.ito at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-async-queue at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Async-Queue>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Async::Queue


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Async-Queue>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Async-Queue>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Async-Queue>

=item * Search CPAN

L<http://search.cpan.org/dist/Async-Queue/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Toshio Ito.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Async::Queue
