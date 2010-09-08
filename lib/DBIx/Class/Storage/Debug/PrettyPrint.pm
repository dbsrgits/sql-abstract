package DBIx::Class::Storage::Debug::PrettyPrint;

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

sub print {
  my $self = shift;
  my $string = shift;

  my $formatted = $self->_sqlat->format($string);

  $self->next::method($formatted, @_);
}

1;

=pod

=head1 SYNOPSIS

 package MyApp::Schema;

 use parent 'DBIx::Class::Schema';

 use DBIx::Class::Storage::Debug::PrettyPrint;

 __PACKAGE__->load_namespaces;

 my $pp = DBIx::Class::Storage::Debug::PrettyPrint->new({
   profile => 'console',
 });

 sub connection {
   my $self = shift;

   my $ret = $self->next::method(@_);

   $self->storage->debugobj($pp);

   $ret
 }

