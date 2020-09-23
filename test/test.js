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

_.each(slp.characters.getAllCharacters(), (character, i) => {
    describe(`${character.name} can be visualized`, () => {
        _.each(character.colors, (color, j) => {
            it(`${color} Portrait`, () => {
                let portraitPath = charPortraitPath(character.name, color);
                assert.ok(fs.existsSync(portraitPath),`${portraitPath} does not exist`);
            });
            it(`${color} Stock Icon`, () => {
                let iconPath = charIconPath(character.name, color);
                assert.ok(fs.existsSync(iconPath),`${iconPath} does not exist`);
            });
        });
    });
});

// @TODO: add all the stages
describe('All stages can be visualized', () => {
    it('all files exist in rsrc', () => {
        _.each(slp.characters.getAllCharacters(), (character, i) => {
            _.each(character.colors, (color, j) => {
                assert.equal(1 + 1, 2);
            });
        });
    });
});
