package DBIx::Class::Storage::Debug::PrettyPrint;

use strict;
use warnings;

use base 'DBIx::Class::Storage::Statistics';

use SQL::Abstract::Tree;

__PACKAGE__->mk_group_accessors( simple => '_sqlat' );
__PACKAGE__->mk_group_accessors( simple => '_clear_line_str' );
__PACKAGE__->mk_group_accessors( simple => '_executing_str' );
__PACKAGE__->mk_group_accessors( simple => '_show_progress' );

sub new {
   my $class = shift;
   my $args  = shift;

   my $clear_line = $args->{clear_line} || "\r[J";
   my $executing  = $args->{executing}  || eval { require Term::ANSIColor } ? do {
       my $c = \&Term::ANSIColor::color;
       $c->('blink white on_black') . 'EXECUTING...' . $c->('reset');;
   } : 'EXECUTING...';
   my $show_progress = defined $args->{show_progress} ? $args->{show_progress} : 1;

   my $sqlat = SQL::Abstract::Tree->new($args);
   my $self = $class->next::method(@_);
   $self->_clear_line_str($clear_line);
   $self->_executing_str($executing);
   $self->_show_progress($show_progress);

   $self->_sqlat($sqlat);

   return $self
}

sub print {
  my $self = shift;
  my $string = shift;
  my $bindargs = shift || [];

  my ($lw, $lr);
  ($lw, $string, $lr) = $string =~ /^(\s*)(.+?)(\s*)$/s;

  local $self->_sqlat->{fill_in_placeholders} = 0 if defined $bindargs
    && defined $bindargs->[0] && $bindargs->[0] eq q('__BULK_INSERT__');

  my $use_placeholders = !!$self->_sqlat->fill_in_placeholders;

  # DBIC pre-quotes bindargs
  $bindargs = [map { s/^'//; s/'$//; $_ } @{$bindargs}] if $use_placeholders;

  my $formatted = $self->_sqlat->format($string, $bindargs);

  $formatted = "$formatted: " . join ', ', @{$bindargs}
     unless $use_placeholders;

  $self->next::method("$lw$formatted$lr", @_);
}

sub query_start {
  my ($self, $string, @bind) = @_;

  if(defined $self->callback) {
    $string =~ m/^(\w+)/;
    $self->callback->($1, "$string: ".join(', ', @bind)."\n");
    return;
  }

  $string =~ s/\s+$//;

  $self->print("$string\n", \@bind);

  $self->debugfh->print($self->_executing_str) if $self->_show_progress
}

sub query_end {
  $_[0]->debugfh->print($_[0]->_clear_line_str) if $_[0]->_show_progress
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

