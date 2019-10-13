package DBIx::Class::SQLMaker::Role::SQLA2Passthrough;

use Role::Tiny;

around select => sub {
  my ($orig, $self, $table, $fields, $where, $rs_attrs, $limit, $offset) = @_;

  $fields = \[ $self->render_expr({ -list => [
    grep defined,
    map +(ref($_) eq 'HASH'
          ? do {
              my %f = %$_;
              my $as = delete $f{-as};
              my ($f, $rhs) = %f;
              my $func = +{ "-${f}" => $rhs };
              ($as
                ? +{ -op => [ 'as', $func, { -ident => [ $as ] } ] }
                : $func)
            }
          : $_), ref($fields) eq 'ARRAY' ? @$fields : $fields
  ] }, -ident) ];

  if (my $gb = $rs_attrs->{group_by}) {
    $rs_attrs = {
      %$rs_attrs,
      group_by => \[ $self->render_expr({ -list => $gb }, -ident) ]
    };
  }
  $self->$orig($table, $fields, $where, $rs_attrs, $limit, $offset);
});

1;
