package Chunkstrumenter;

use strictures 2;
use Class::Method::Modifiers qw(install_modifier);
use Data::Dumper::Concise;
use Context::Preserve;

require SQL::Abstract;

open my $log_fh, '>>', 'chunkstrumenter.log';

install_modifier 'SQL::Abstract', around => '_order_by_chunks' => sub {
  my ($orig, $self) = (shift, shift);
  my @args = @_;
  preserve_context { $self->$orig(@args) }
    after => sub {
      my $dumped = Dumper([ $self->{quote_char}, \@args, \@_ ]);
      $dumped =~ s/\n\Z/,\n/;
      print $log_fh $dumped;
    };
};

1;
