package SQL::Abstract::Formatter;

require SQL::Abstract::Parts; # it loads us too, don't cross the streams

use Moo;

has indent_by => (is => 'ro', default => '  ');
has max_width => (is => 'ro', default => 78);

sub _join {
  shift;
  return SQL::Abstract::Parts::stringify(\@_);
}

sub format {
  my ($self, $join, @parts) = @_;
  $self->_fold_sql('', '', @{$self->_simplify($join, @parts)});
}

sub _simplify {
  my ($self, $join, @parts) = @_;
  return '' unless @parts;
  return $parts[0] if @parts == 1 and !ref($parts[0]);
  return $self->_simplify(@{$parts[0]}) if @parts == 1;
  return [ $join, map ref() ? $self->_simplify(@$_) : $_, @parts ];
}

sub _fold_sql {
  my ($self, $indent0, $indent, $join, @parts) = @_;
  my @res;
  my $w = $self->max_width;
  my $join_len = 0;
  (s/, \z/,\n/ and $join_len = 1)
    or s/\A /\n/
    or $_ = "\n"
      for my $line_join = $join;
  my ($nl_pre, $nl_post) = split "\n", $line_join, -1;
  my $line = $indent0;
  my ($lead0) = $indent0 =~ /\A(\s*)/;
  my $fresh = 1; # $line holds no part of this level yet
  my $line_proto = $indent.$nl_post;
  PART: foreach my $idx (0..$#parts) {
    my $p = $parts[$idx];
    my $last = $idx == $#parts;
    my $pre = $fresh ? '' : $join;
    my $j_part = $pre.(my $j = ref($p) ? $self->_join(@$p) : $p);
    if (length($j_part) + length($line) + $join_len <= $w) {
      $line .= $j_part;
      $fresh = 0;
      next PART;
    }
    if (ref($p) and $p->[1] eq '(' and $p->[-1] eq ')') {
      my ($lead) = $line =~ /\A(\s*)/;
      my $innerdent = $lead.$self->indent_by;
      push @res, $line.$pre.'('."\n";
      my @inner = @{$p}[2 .. $#$p - 1];
      my $folded = $self->_fold_sql($innerdent, $innerdent,
        (@inner == 1 and ref($inner[0])) ? @{$inner[0]} : ($p->[0], @inner)
      );
      push @res, $folded."\n";
      $line = $lead.')';
      $fresh = 0;
      next PART;
    }
    my $innerdent = (@res ? $indent : $lead0).$self->indent_by;
    my $start = $fresh ? $line : $line_proto;
    push @res, $line.$nl_pre."\n" unless $fresh;
    $line = $start.$j;
    $fresh = 0;
    next PART if !ref($p) or length($line) <= $w;
    my $folded = $self->_fold_sql($start, $innerdent, @$p);
    push @res, $folded.($last ? '' : $nl_pre."\n");
    $line = $last ? '' : $line_proto;
    $fresh = 1;
  }
  return join '', @res, $line;
}

1;
