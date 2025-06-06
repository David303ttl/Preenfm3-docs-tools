# Preenfm3-docs-tools
A modest repository of my tools and documents for Preenfm3. More as a proof of concept, an exercise.
## Docs
WIP. I'm collecting scattered info from the forum, code, residual manual so that you don't have to waste your time on this (searching) anymore. 
## Renoise tool
PoC can I make a tool that will receive and send values between Renoise and Pfm3. Using the NRPN list I took the ones I needed and suddenly I have a panel with all the operators and envelopes in one place. Happy days.

Later, however, I wanted to get around the limitations of the Renoise tool a bit and be able to modulate the same parameters. 
Nothing fancy, just an instrument without a gui to give access to the parameters. 
And here came Reaper with its JSFX and ysfx
## JSFX NRPN controller 
The only slider for midi channel selection. The rest exposed as parameters. I divided into a controller for operators and envelopes and a separate one for modulators and modulation matrix (here I omitted step seq). The code looks like what it looks like, first effect. Hard-coded to arrange Op's and ADSR's in the right (for me) order.
How to use:
If you don't use Reaper DAW, install ysfx and select the plug-in and jsfx file in your DAW. Easy-peasy. By the way, take a look at the fantastic jsfx's from Reaper.
It gets the job done, that's what I needed. 
