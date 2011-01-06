package t::Util;

use strict;
use warnings;

use IO::File q[SEEK_SET];
use IO::Dir;

BEGIN {
    our @EXPORT_OK = qw(
        rewind
        tmpfile
        dir_list
        slurp
        parse_case
        sort_headers
        set_socket_source
        monkey_patch
        $CRLF
        $LF
    );

    require Exporter;
    *import = \&Exporter::import;
}

our $CRLF = "\x0D\x0A";
our $LF   = "\x0A";

sub rewind(*) {
    seek($_[0], 0, SEEK_SET)
      || die(qq/Couldn't rewind file handle: '$!'/);
}

sub tmpfile {
    my $fh = IO::File->new_tmpfile
      || die(qq/Couldn't create a new temporary file: '$!'/);

    binmode($fh)
      || die(qq/Couldn't binmode temporary file handle: '$!'/);

    if (@_) {
        print({$fh} @_)
          || die(qq/Couldn't write to temporary file handle: '$!'/);

        seek($fh, 0, SEEK_SET)
          || die(qq/Couldn't rewind temporary file handle: '$!'/);
    }

    return $fh;
}

sub dir_list {
    my ($dir, $filter) = @_;
    $filter ||= qr/./;
    my $d = IO::Dir->new($dir)
        or return;
    return map { "$dir/$_" } grep { /$filter/ } grep { /^[^.]/ } $d->read;
}

sub slurp (*) {
    my ($fh) = @_;

    rewind($fh);

    binmode($fh)
      || die(qq/Couldn't binmode file handle: '$!'/);

    my $exp = -s $fh;
    my $buf = do { local $/; <$fh> };
    my $got = length $buf;

    ($exp == $got)
      || die(qq[I/O read mismatch (expexted: $exp got: $got)]);

    return $buf;
}

sub parse_case {
    my ($case) = @_;
    my %args;
    my $key = '';
    for my $line ( split "\n", $case ) {
        chomp $line;
        if ( substr($line,0,1) eq q{ } ) {
            $line =~ s/^\s+//;
            push @{$args{$key}}, $line;
        }
        else {
            $key = $line;
        }
    }
    return \%args;
}

sub sort_headers {
    my ($text) = shift;
    my @lines = split /$CRLF/, $text;
    my @output = shift(@lines);
    push @output, sort @lines;
    return join($CRLF, @output);
}

{
    my ($req_fh, $res_fh);

    sub set_socket_source {
        ($req_fh, $res_fh) = @_;
    }

    sub monkey_patch {
        no warnings qw/redefine once/;
        *HTTP::Tiny::Handle::can_read = sub {1};
        *HTTP::Tiny::Handle::can_write = sub {1};
        *HTTP::Tiny::Handle::connect = sub {
            my ($self, $scheme, $host, $port) = @_;
            $self->{host} = $host;
            $self->{port} = $port;
            $self->{fh} = $req_fh;
            return $self;
        };
        my $original_write_request = \&HTTP::Tiny::Handle::write_request;
        *HTTP::Tiny::Handle::write_request = sub {
            my ($self, $request) = @_;
            $original_write_request->($self, $request);
            $self->{fh} = $res_fh;
        }
    }
}

1;


# vim: et ts=4 sts=4 sw=4:
