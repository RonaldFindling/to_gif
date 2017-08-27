# to_gif
Linux shell script to align multiple *jpg* images and convert into an animated *gif*

<h4>Dependencies (all part of the ubuntu repositories):</h4>

+ exiv2
+ gifsicle
+ hugin
+ imagemagick

<h4>Installation:</h4>
If all dependencies are correctly installed and available on the `$PATH` copy **to_gif.sh** into your `$PATH` and make it executable.
Then copy its manpage **to_gif.sh.1** into a directory shown by `manpath`.

<h4>Exemplary usage:</h4>

```bash
to_gif.sh *.img
to_gif.sh -d 100 -s 90 *.img
```

<h4>Help:</h4>

```bash
man to_gif.sh
to_gif.sh -h
```
