# Which kind of data a run is on: "real", "synth" or "unknown"

The user states it in the config as `data.tag`. It decides where figures
are written (only "real" goes under `output/`). Nothing is guessed: when
`data.tag` is not set, an interactive session asks once (r = real, s =
synthetic/test, n = stop), and a non-interactive session (Rscript, CI,
tests, knitting) stops with an error saying what to add to the config.
The answer applies to this run only; the config file is not changed.

## Usage

``` r
resolve_data_tag(cfg, ask = .is_interactive(), read = readline)
```

## Arguments

- cfg:

  A configuration list.

- ask:

  Ask when `data.tag` is not set? Default `.is_interactive()`.

- read:

  Function that shows a prompt and returns the typed answer (default
  `readline`); replaceable for testing.

## Value

A list with `tag` and `source` ("config" when stated in the config,
"asked at run time" when answered at the prompt).
