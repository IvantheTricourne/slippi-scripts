<h1 align="center">Slippi Scripts</h1>

<div align="center">

A collection of Slippi scripts and other vaguely useful things.

[![Build Status](https://travis-ci.com/IvantheTricourne/slippi-scripts.svg?branch=master)](https://travis-ci.com/IvantheTricourne/slippi-scripts)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://github.com/IvantheTricourne/slippi-scripts/blob/master/LICENSE.txt)
<a href="https://patreon.com/setBaNG"><img src="https://img.shields.io/endpoint.svg?url=https://moshef9.wixsite.com/patreon-badge/_functions/badge/?username=setBaNG" alt="Patreon donate button" /> </a>
</div>

## how

You'll need [`node` and `npm`](https://nodejs.org/en/download/).

`npm install`

Then depending on what you want to do (see below), run a script using `node`.

`node src/<SOME_SCRIPT>`

## what

For usage information, see the `--help` option for any of the scripts below.

1. Generate stats for a set of `.slp` files: `src/getStats.js`
   * outputs a `stats.json` file for use in the included _Slippi Stats Viewer_ app.
   * to run _Slippi Stats Viewer_, `npm start`

![](demo/demo.gif)
2. Generate a playback queue for several `.slp` files (and optionally a highlight reel): `src/getGames.js`
   * provides general versus info (e.g. opponent tags, names, codes, etc.)
   * provides total play time on a per opponent basis
3. Play/record the queue from (1): `src/playback.js`
   * requires [OBS](https://obsproject.com/) with [`obs-websocket`](https://obsproject.com/forum/resources/obs-websocket-remote-control-obs-studio-from-websockets.466/) installed
   * requires a pre-setup `config.json`
