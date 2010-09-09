package DBIx::Class::Storage::Debug::PrettyPrint;

use strict;
use warnings;

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
  my $bindargs = shift || [];

  my $use_placeholders = !!$self->_sqlat->fill_in_placeholders;

  # DBIC pre-quotes bindargs
  $bindargs = [map { s/^'//; s/'$//; } @{$bindargs}] if $use_placeholders;

  my $formatted = $self->_sqlat->format($string, $bindargs) . "\n";

  $formatted = "$formatted: " . join ', ', @{$bindargs}
     unless $use_placeholders;

  $self->next::method($formatted, @_);
}

sub query_start {
  my ($self, $string, @bind) = @_;

  if(defined $self->callback) {
    $string =~ m/^(\w+)/;
    $self->callback->($1, "$string: ".join(', ', @bind)."\n");
    return;
  }

  $self->print($string, \@bind);
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

