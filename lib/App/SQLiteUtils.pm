package App::SQLiteUtils;

use 5.010001;
use strict;
use warnings;
use Log::ger;

use Expect;

# AUTHORITY
# DATE
# DIST
# VERSION

our %SPEC;

sub _connect {
    require DBI;

    my $args = shift;
    DBI->connect("dbi:SQLite:dbname=$args->{db_file}", undef, undef, {RaiseError=>1});
}

our %args_common = (
    db_file => {
        schema => 'filename*',
        req => 1,
        pos => 0,
    },
);

our %arg1_table = (
    table => {
        schema => ['str*', min_len=>1],
        req => 1,
        pos => 1,
    },
);

our %argopt_table = (
    table => {
        schema => 'str*',
    },
);

$SPEC{list_sqlite_tables} = {
    v => 1.1,
    description => <<'_',

See also the `.tables` meta-command of the `sqlite3` CLI.

_
    args => {
        %args_common,
    },
    result_naked => 1,
};
sub list_sqlite_tables {
    require DBIx::Util::Schema;

    my %args = @_;
    my $dbh = _connect(\%args);
    [DBIx::Util::Schema::list_tables($dbh)];
}

$SPEC{list_sqlite_columns} = {
    v => 1.1,
    description => <<'_',

See also the `.schema` and `.fullschema` meta-command of the `sqlite3` CLI.

_
    args => {
        %args_common,
        %arg1_table,
    },
    result_naked => 1,
};
sub list_sqlite_columns {
    require DBIx::Util::Schema;

    my %args = @_;
    my $dbh = _connect(\%args);
    [DBIx::Util::Schema::list_columns($dbh, $args{table})];
}

$SPEC{import_csv_to_sqlite} = {
    v => 1.1,
    summary => 'Import a CSV file into SQLite database',
    description => <<'_',

This tool utilizes the `sqlite3` command-line client to import a CSV file into
SQLite database. It pipes the following commands to the `sqlite3` CLI:

    .mode csv
    .import FILENAME TABLENAME

where FILENAME is the CSV filename and TABLENAME is the table name. If the
`table` option is not specified, the table name will be derived from the CSV
filename (e.g. 'stdin' for '-', 't1' for '/path/to/t1.csv', 'table2' for
'./2.csv' and so on).

_
    args => {
        %args_common,
        csv_file => {
            schema => 'filename*',
            default => '-',
            pos => 1,
        },
        %argopt_table,
        # XXX allow customizing Expect timeout, for larger table
    },
    deps => {
        prog => 'sqlite3', # XXX allow customizing path?
    },
};
sub import_csv_to_sqlite {
    require DBIx::Util::Schema;
    require Expect;
    require File::Temp;
    require String::ShellQuote;

    my %args = @_;
    my $csv_file = $args{csv_file} // '-';

    my $dbh = _connect(\%args);

    my $table = $args{table};
  PICK_TABLE_NAME: {
        last if defined $table;
        if ($csv_file eq '-') {
            $table = 'stdin';
            last;
        }
        $table = $csv_file;
        $table =~ s!.+/!!;
        $table =~ s!(?:\.\w+)+\z!!;
        $table =~ s!\W+!_!g;
        $table = "t" unless length $table;
        $table = "t$table" if $table =~ /\A[0-9]/;
        my $table0 = $table;
        my $i = 1;
        while (DBIx::Util::Schema::table_exists($dbh, $table)) {
            $i++;
            $table = "${table0}_$i";
        }
        log_trace "Picking table name: %s", $table;
    }

    if ($csv_file eq '-') {
        my ($tempfh, $tempfile) = File::Temp::tempfile();
        print $tempfh while <STDIN>;
        close $tempfh;
        $csv_file = $tempfile;
    }

    $dbh->disconnect; # we're releasing any locks, for sqlite3 CLI client

    my $exp = Expect->spawn("sqlite3", $args{db_file})
        or die "import_csv_to_sqlite(): Cannot spawn command: $!\n";
    if (log_is_trace()) { $exp->exp_internal(1) }
    unless (log_is_trace()) { $exp->log_stdout(0) }
    #$exp->debug(3);

    $exp->expect(
        2,
        [
            qr/sqlite> $/,
            sub {
                my $self = shift;
                $exp->clear_accum;
                $exp->send(".mode csv\n");
            },
        ],
        [
            'eof',
            sub {
                die "sqlite3 exits prematurely";
            },
        ],
        [
            'timeout',
            sub {
                die "Unexpected sqlite3 response";
            },
        ],
    );

    $exp->expect(
        2,
        [
            qr/sqlite> $/,
            sub {
                my $self = shift;
                $exp->clear_accum;
                $exp->send(".import ". String::ShellQuote::shell_quote($csv_file) . " \"" . $table . "\"\n");
            },
        ],
        [
            'eof',
            sub {
                die "sqlite3 exits prematurely";
            },
        ],
        [
            'timeout',
            sub {
                die "Unexpected sqlite3 response";
            },
        ],
    );

    $exp->expect(
        30,
        [
            qr/Error: (.+)/,
            sub {
                my $self = shift;
                $exp->clear_accum;
                my @m = $exp->matchlist;
                die "Can't import: $m[0]";
            },
        ],
        [
            qr/sqlite> $/,
            sub {
                my $self = shift;
                # import success
            },
        ],
        [
            'eof',
            sub {
                die "sqlite3 exits prematurely";
            },
        ],
        [
            'timeout',
            sub {
                die "Unexpected sqlite3 response";
            },
        ],
    );

    # there's still a ~1 second delay which i don't know how to avoid yet,
    # including with hard_close().
    #$exp->hard_close;

    [200, "OK", undef, {
        'func.table' => $table,
        'cmdline.result' => "Imported to table $table",
    }];
}

1;
# ABSTRACT: Utilities related to SQLite

=head1 DESCRIPTION

This distribution includes several utilities:

#INSERT_EXECS_LIST


=head1 SEE ALSO

L<App::DBIUtils>
