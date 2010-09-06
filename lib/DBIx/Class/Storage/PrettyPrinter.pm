package DBIx::Class::Storage::PrettyPrinter;

use base 'DBIx::Class::Storage::Statistics';

use SQL::Abstract::Tree;

__PACKAGE__->mk_group_accessors( simple => '_sqlat' );

sub new {
	my $class = shift;

	my $sqlat = SQL::Abstract::Tree->new(shift @_);
	my $self = $class->next::method(@_);

	$self->_sqlat($sqlat);

	return $self
}

sub query_start {
  my $self = shift;
  my $string = shift;

  my $formatted = $self->_sqlat->format($string);

  $self->next::method($formatted, @_);
}

1;
