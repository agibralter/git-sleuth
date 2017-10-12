# Warning

THIS WAS MOSTLY JUST ME HACKING AROUND. IT MAY BE WRONG!

# Dependencies

crystal-lang

`brew install crystal-lang`

# Usage

1. Run `make` to build binary.
2. Run `./sleuth [path-to-repo] [start-date]`.
   E.g.: `./sleuth ../some-repo '2016-01-01'`.

Produces a csv with the following format:

```
| author | file           | lines added | lines removed |
| Jane   | app/foo/bar.rb | 1032        | 324           |
| Bob    | app/baz.js     | 13          | 4             |
```
