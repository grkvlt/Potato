POTATO 1.0.1-SNAPSHOT
=====================

**Experimental Video Processing.**

Based on previous [Vegetables](https://github.com/grkvlt/Vegetables/) sketch.

The following process is used:

- Grayscale conversion
  - Quantization
  - Gamma correction
  - Brightness adjustment
- Downsample and average
- Differentiate (with gradient threshold)
- De-noise (with neighbour threshold)

The process is paramaterised using the following variables and default values,
withing the given constraints:

- Subsampling window: **4** [_2_,_128_]
- Gradient threshold: **0.25** [_0.0_,_1.0_]
- Neighbour count: **6** [_1_,_9_]
- Gamma: **1.0** [_0.1_,_5.0_]
- Brightness: **1.0** [_0.1_,_5.0_]
- Levels: **16**

![Potato](https://raw.githubusercontent.com/grkvlt/Potato/master/potato.png)

## Instructions

When running, the parameters can be changed using the number keys, and the `v`,
`g` and `z` keys will toggle display of video, grayscale conversion and de-noising.
The spacebar will save the current image and `q` will quit the program. The
current parameter values are displayed in an info banner at the top of the screen.
Press 'r' to reset the parameters to their initial values.

---
_Copyright 2009-2017 by [Andrew Donald Kennedy](mailto:andrew.international@gmail.com)
and Licensed under the [Apache Software License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0)_
