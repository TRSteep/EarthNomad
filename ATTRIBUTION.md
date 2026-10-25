# Third-party assets

All planetary texture maps and the star panorama are by **Solar System Scope / INOVE**, licensed under **Creative Commons Attribution 4.0 International**.

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

Changes: file relocation/renaming only; engine import generates mipmaps. Mobile runtime resizes images to 2048×1024. Rendering applies illumination, atmosphere, night-light blending and color processing; these visual changes are not changes to the source JPEGs. Saturn rings, UI icon and shader code are original procedural assets.

## Data

NASA/JPL Solar System Dynamics: Approximate Positions of the Planets, Table 1 (1800–2050).
https://ssd.jpl.nasa.gov/planets/approx_pos.html

`assets/elements.json` transcribes six elements and six rates per planet. Earth entry is Earth–Moon barycenter. `docs/jpl-elements.html` is the downloaded source reference.

## Engine

Godot Engine © 2014–present Godot contributors; © 2007–2014 Juan Linietsky, Ariel Manzur. MIT license, https://godotengine.org/license/. The Windows executable contains the Godot runtime and its third-party components. Full license notices: https://github.com/godotengine/godot/blob/4.5-stable/COPYRIGHT.txt and https://github.com/godotengine/godot/blob/4.5-stable/LICENSE.txt.
