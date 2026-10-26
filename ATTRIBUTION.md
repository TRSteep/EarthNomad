# Third-party assets

The original planetary texture maps, Moon map and star panorama are by **Solar System Scope / INOVE**, licensed under **Creative Commons Attribution 4.0 International**. Other satellite maps added in v0.4.0 are NASA/USGS mission products, detailed below.

- Author and original collection: https://www.solarsystemscope.com/textures/
- License: https://creativecommons.org/licenses/by/4.0/
- The source describes maps based on NASA elevation and imagery, with some artistic gap filling and enhanced colors. They are not live surface/weather observations.

## Files and provenance

| Local file | Original filename |
|---|---|
| assets/textures/sun.jpg | 2k_sun.jpg |
| assets/textures/mercury.jpg | 2k_mercury.jpg |
| assets/textures/venus.jpg | 2k_venus_surface.jpg |
| assets/textures/venus_clouds.jpg | 2k_venus_atmosphere.jpg |
| assets/textures/earth.jpg | 2k_earth_daymap.jpg |
| assets/textures/mars.jpg | 2k_mars.jpg |
| assets/textures/jupiter.jpg | 2k_jupiter.jpg |
| assets/textures/saturn.jpg | 2k_saturn.jpg |
| assets/textures/uranus.jpg | 2k_uranus.jpg |
| assets/textures/neptune.jpg | 2k_neptune.jpg |
| assets/textures/8k_earth_daymap.jpg | 8k_earth_daymap.jpg |
| assets/textures/8k_earth_nightmap.jpg | 8k_earth_nightmap.jpg |
| assets/textures/8k_earth_clouds.jpg | 8k_earth_clouds.jpg |
| assets/textures/8k_stars_milky_way.jpg | 8k_stars_milky_way.jpg |

Original download URLs have the form `https://www.solarsystemscope.com/textures/download/<original filename>`.

The original host returned HTTP 403 in this environment. Identical-source assets were obtained from these public mirrors:

- 2K albedo maps: https://github.com/RTF22/Orrery/tree/master/assets-quellen/texturen — provenance https://github.com/RTF22/Orrery/blob/master/ASSETS.md
- Earth layers and panorama: https://github.com/ZGdadong/Three.js-3D-Earth/tree/main/images (downloaded through jsDelivr)
- Venus cloud deck: https://github.com/TanvirAhmedArnab/SolarSystem/blob/main/SourceAssets/ThirdParty/Textures/SolarSystemScope/2k_venus_atmosphere.jpg (Git LFS media)

Changes: file relocation/renaming only; engine import generates mipmaps. Mobile runtime resizes images to 2048×1024. Rendering applies illumination, atmosphere, night-light blending and color processing; these visual changes are not changes to the source JPEGs. Saturn/Uranus rings, UI icon and shader code are original procedural assets based on the data sources below.

## Satellite surface maps · v0.4.0

Local directory: `assets/textures/moons/`. Source JPEGs are kept unchanged; the following processing describes the source mirror, not additional modifications in EarthNomad.

- `moon.jpg`: Solar System Scope `2k_moon.jpg`, CC BY 4.0, 2048×1024. Mirror: https://github.com/RTF22/Orrery/blob/master/assets-quellen/texturen/moon/albedo.jpg
- `deimos.jpg`, `miranda.jpg`, `ariel.jpg`, `umbriel.jpg`, `titania.jpg`, `oberon.jpg`: NASA 3D Resources, 1440×720, NASA/USGS/JPL mission mosaics. Direct source tree: https://github.com/nasa/NASA-3D-Resources/tree/master/Images%20and%20Textures . Each file is under `<Planet> - <Moon>/<Planet> - <Moon>.jpg` (Mars for Deimos, Uranus for the others). Credit: NASA/JPL/Caltech; Uranian maps: USGS/Tammy Becker & JPL/Caltech. NASA description: https://science.nasa.gov/3d-resources/uranus-miranda/
- The remaining maps below are NASA/USGS public-domain mosaics mirrored at `https://github.com/RTF22/Orrery/blob/master/assets-quellen/texturen/<id>/albedo.jpg`, at 1024×512. Per-file provenance: https://github.com/RTF22/Orrery/blob/master/ASSETS.md . Mirror processing includes downscaling, border cropping for Mimas/Iapetus, and slight resizing where original aspect ratios differ.

| Local file | Mission map / author | Original source page |
|---|---|---|
| io.jpg | USGS Astrogeology, Galileo/Voyager | https://commons.wikimedia.org/wiki/File:Io_for_GeoHacks.jpg |
| europa.jpg | NASA/JPL/USGS, Voyager | https://commons.wikimedia.org/wiki/File:Jupiter_II-Europa_map_NASA_JPL_Voyager.jpg |
| ganymede.jpg | NASA/JPL/USGS, Voyager | https://commons.wikimedia.org/wiki/File:Ganymede_map_NASA_JPL_Voyager.jpg |
| callisto.jpg | USGS Astrogeology | https://commons.wikimedia.org/wiki/File:Callisto_USGS_global_small.jpg |
| phobos.jpg | PDS / Phil Stooke, Viking | https://commons.wikimedia.org/wiki/File:Phobos_Viking_Mosaic_DLRcontrol_7200.jpg |
| mimas.jpg | NASA/JPL-Caltech/SSI, Cassini | https://commons.wikimedia.org/wiki/File:Map_of_Mimas_2017-01_PIA17214.jpg |
| enceladus.jpg | NASA/JPL-Caltech/SSI, Cassini | https://commons.wikimedia.org/wiki/File:Map_of_Enceladus_cropped.jpg |
| tethys.jpg | NASA/JPL-Caltech/SSI, Cassini | https://commons.wikimedia.org/wiki/File:Map_of_Tethys_cropped.jpg |
| dione.jpg | NASA/JPL-Caltech/SSI | https://commons.wikimedia.org/wiki/File:Dione_map_for_GeoHack.jpg |
| rhea.jpg | NASA/JPL-Caltech/SSI, Cassini | https://commons.wikimedia.org/wiki/File:Map_of_Rhea_cropped.jpg |
| titan.jpg | NASA/JPL-Caltech/SSI, infrared map | https://commons.wikimedia.org/wiki/File:Map_of_Titan_cropped.jpg |
| iapetus.jpg | NASA/JPL-Caltech/SSI/LPI, Cassini | https://commons.wikimedia.org/wiki/File:Color_map_of_Iapetus_PIA18436_Nov._2014.jpg |
| triton.jpg | NASA/JPL-Caltech/LPI, Voyager 2 | https://commons.wikimedia.org/wiki/File:Triton_Map.jpg |

NASA media guidance: https://www.nasa.gov/nasa-brand-center/images-and-media/ . These mission maps are not live observations. Black/unmapped regions in Voyager mosaics are retained; the program does not invent terrain for them. Titan's near-infrared surface map is mostly obscured by a rendered orange haze.

## Data

NASA/JPL Solar System Dynamics: Approximate Positions of the Planets, Table 1 (1800–2050).
https://ssd.jpl.nasa.gov/planets/approx_pos.html

`assets/elements.json` transcribes six elements and six rates per planet. Earth entry is Earth–Moon barycenter. `docs/jpl-elements.html` is the downloaded source reference.

`assets/satellites.json` transcribes the selected mean elements, reference planes, radii and GM values from https://ssd.jpl.nasa.gov/sats/elem/ and https://ssd.jpl.nasa.gov/sats/phys_par/ . Periods used for rendering are described in `docs/SATELLITES.md`.

Ring radii/widths and approximate optical depths: NASA/NSSDCA Saturn factsheet, https://nssdc.gsfc.nasa.gov/planetary/factsheet/satringfact.html ; NASA PDS Ring-Moon Systems Node, https://pds-rings.seti.org/uranus/uranus_rings_table.html . Fixed IAU pole directions: NAIF PCK https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/pck00011.tpc . EarthNomad uses a few constants from that kernel, not the SPICE runtime. Synthetic density variation and ring lighting are original approximations, not spacecraft images.

## Engine

Godot Engine © 2014–present Godot contributors; © 2007–2014 Juan Linietsky, Ariel Manzur. MIT license, https://godotengine.org/license/. The Windows executable contains the Godot runtime and its third-party components. Full license notices: https://github.com/godotengine/godot/blob/4.5-stable/COPYRIGHT.txt and https://github.com/godotengine/godot/blob/4.5-stable/LICENSE.txt.
