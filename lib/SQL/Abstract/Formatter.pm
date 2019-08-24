package SQL::Abstract::Formatter;

require SQL::Abstract::Parts; # it loads us too, don't cross the streams

use Moo;

has indent_by => (is => 'ro', default => '  ');
has max_width => (is => 'ro', default => 78);

sub _join {
  shift;
  SQL::Abstract::Parts::stringify(\@_);
}

sub format {
  my ($self, $join, @parts) = @_;
  my $sql = $self->_join($join, @parts);
  return $sql unless length($sql) > $self->max_width;
  local $self->{max_width} = $self->{max_width} - length($self->indent_by);
  return join("\n", map ref() ? $self->format(@$_) : $_, @parts);
}

1;  
