package Perl::Metrics::Maintainability;
use v5.36;
use strict;
use warnings;

use Moo;
use List::AllUtils qw/all max/;
use Perl::Metrics::Halstead;
use Perl::Metrics::Simple;
use Perl::Metrics::Maintainability::Result;

use namespace::clean;

our $VERSION = 0.10;

has analyzer => (
    is => 'lazy',
    builder => 1,
);

sub _build_analyzer {
    my ($self) = @_;
    return Perl::Metrics::Simple->new();
}

has paths => (
    is => 'ro',
    required => 1,
);

sub analyze {
    my ($self) = @_;

    my $results = [];
    for my $path (@{$self->paths}) {
        my @list = $self->analyzer->list_perl_files($path);
        push @$results, $self->_calc_by_files(\@list);
    }

    return $results;
}

sub _calc_by_files {
    my ($self, $list_of_files) = @_;

    my @results = ();

    for my $file (@$list_of_files) {
        my $result = $self->_calc_by_file($file);
        push @results, $result if defined $result;
    }

    return @results;
}

sub _calc_by_file {
    my ($self, $path) = @_;

    my $volume;
    eval {
        $volume = Perl::Metrics::Halstead->new(file => $path)->volume;
    };
    return if $@;

    my $analysis = $self->analyzer->analyze_files($path);

    my $loc = $analysis->lines;
    my $cc  = $self->_calc_cc($analysis);
    my $mi  = $self->_calc_mi($volume, $cc, $loc);

    return Perl::Metrics::Maintainability::Result->new(
        mi     => $mi,
        loc    => $loc,
        cc     => $cc,
        volume => $volume,
        path   => $path,
    );
}

sub _calc_cc {
    my ($self, $analysis) = @_;

    my $main_max_cc = $analysis->summary_stats->{main_complexity}->{max} // 0;
    my $sub_max_cc  = $analysis->summary_stats->{sub_complexity}->{max} // 0;
    return max($main_max_cc, $sub_max_cc);
}

# https://docs.microsoft.com/ja-jp/visualstudio/code-quality/code-metrics-maintainability-index-range-and-meaning?view=vs-2022
sub _calc_mi {
    my ($self, $volume, $cc, $loc) = @_;
    return max(0, (171 - 5.2 * log($volume) - 0.23 * $cc - 16.2 * log($loc)) * 100 / 171);
}

1;
__END__

=head1 NAME

Perl::Metrics::Maintainability - Analyze maintainability index of Perl files.

=cut
