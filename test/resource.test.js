const assert = require('assert');
const fs = require('fs');
const _ = require('lodash');
const path = require('path');
const slp = require('slp-parser-js');

// @NOTE: copy from elm
// @TODO: maybe do this purely in getStats
function charPortraitPath(charName, charColor) {
    return path.join(process.cwd(), `rsrc/Characters/Portraits/${charName}/${charColor}.png`);
}

function charIconPath(charName, charColor) {
    return path.join(process.cwd(), `rsrc/Characters/Stock Icons/${charName}/${charColor}.png`);
}

function fourStockCharIconPath(charName, charColor) {
    return path.join(process.cwd(), `rsrc/Characters/Stock Icons/${charName}/${charColor}G.png`);
}

function stageIconPath(stageName) {
    return path.join(process.cwd(), `rsrc/Stages/Icons/${stageName}.png`);
}

_.each(slp.characters.getAllCharacters(), (character, i) => {
    describe(`${character.name} can be visualized`, () => {
        _.each(character.colors, (color, j) => {
            it(`${color} Portrait`, () => {
                let portraitPath = charPortraitPath(character.name, color);
                assert.ok(fs.existsSync(portraitPath), `${portraitPath} does not exist`);
            });
            it(`${color} Stock Icon`, () => {
                let iconPath = charIconPath(character.name, color);
                assert.ok(fs.existsSync(iconPath), `${iconPath} does not exist`);
            });
            it(`${color} Four Stock Icon`, () => {
                let fourStockIconPath = fourStockCharIconPath(character.name, color);
                assert.ok(fs.existsSync(fourStockIconPath), `${fourStockIconPath} does not exist`);
            });
        });
    });
});

// from @slippi/slipp-js
const stages = {
    2: {
        id: 2,
        name: "Fountain of Dreams",
    },
    3: {
        id: 3,
        name: "Pokémon Stadium",
    },
    4: {
        id: 4,
        name: "Princess Peach's Castle",
    },
    5: {
        id: 5,
        name: "Kongo Jungle",
    },
    6: {
        id: 6,
        name: "Brinstar",
    },
    7: {
        id: 7,
        name: "Corneria",
    },
    8: {
        id: 8,
        name: "Yoshi's Story",
    },
    9: {
        id: 9,
        name: "Onett",
    },
    10: {
        id: 10,
        name: "Mute City",
    },
    11: {
        id: 11,
        name: "Rainbow Cruise",
    },
    12: {
        id: 12,
        name: "Jungle Japes",
    },
    13: {
        id: 13,
        name: "Great Bay",
    },
    14: {
        id: 14,
        name: "Hyrule Temple",
    },
    15: {
        id: 15,
        name: "Brinstar Depths",
    },
    16: {
        id: 16,
        name: "Yoshi's Island",
    },
    17: {
        id: 17,
        name: "Green Greens",
    },
    18: {
        id: 18,
        name: "Fourside",
    },
    19: {
        id: 19,
        name: "Mushroom Kingdom I",
    },
    20: {
        id: 20,
        name: "Mushroom Kingdom II",
    },
    22: {
        id: 22,
        name: "Venom",
    },
    23: {
        id: 23,
        name: "Poké Floats",
    },
    24: {
        id: 24,
        name: "Big Blue",
    },
    25: {
        id: 25,
        name: "Icicle Mountain",
    },
    // 26: {
    //   id: 26,
    //   name: "Icetop",
    // },
    27: {
        id: 27,
        name: "Flat Zone",
    },
    28: {
        id: 28,
        name: "Dream Land N64",
    },
    29: {
        id: 29,
        name: "Yoshi's Island N64",
    },
    30: {
        id: 30,
        name: "Kongo Jungle N64",
    },
    31: {
        id: 31,
        name: "Battlefield",
    },
    32: {
        id: 32,
        name: "Final Destination",
    },
};

describe('All stages can be visualized', () => {
    _.each(stages, (stage, i) => {
        it(`${stage.name}`, () => {
            let stagePath = stageIconPath(stage.name);
            assert.ok(fs.existsSync(stagePath), `${stagePath} does not exist`);
        });
    });
});
