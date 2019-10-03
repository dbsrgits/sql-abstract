package SQL::Abstract::Plugin::BangOverrides;

use Moo;

with 'SQL::Abstract::Role::Plugin';

sub register_extensions {
  my ($self, $sqla) = @_;
  foreach my $stmt ($sqla->statement_list) {
    $sqla->wrap_expander($stmt => sub ($orig) {
      sub {
        my ($self, $name, $args) = @_;
        my %args = %$args;
        foreach my $clause (map /^!(.*)$/, keys %args) {
          my $override = delete $args{"!${clause}"};
          $args{$clause} = (
            ref($override) eq 'CODE'
              ? $override->($args{$clause})
              : $override
          );
        }
        $self->$orig($name, \%args);
      }
    });
  }
}

1;
