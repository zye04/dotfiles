.pragma library

const COPY = {
    t2i: ["Describe the image", "Subject, setting, light, lens — concrete beats clever.", "Woman in a red wool scarf on an old wooden pier, stormy sea behind her, overcast daylight, 35 mm photo", ["golden hour", "overcast", "35 mm", "shallow depth of field"]],
    edit: ["What should change?", "Describe the change. Ask to keep the rest the same.", "Make her coat dark green and add light rain", ["keep the face", "same lighting"]]
};
const ROLE = { edit: "Will be edited", upscale: "Will be upscaled" };
const BUTTON = { t2i: ["auto_awesome", "Create image"], edit: ["edit", "Edit image"], upscale: ["hd", "Upscale image"], region: ["brush", "Apply region edit"] };
const SHAPES = [["16:9", "landscape"], ["9:16", "portrait"], ["1:1", "square"], ["4:5", "portrait"]];

function appendSuggestion(text, word) {
    const t = text.replace(/[ ,.]*$/, "");
    return t.length ? t + ", " + word : word;
}
function buttonFor(mode) { return BUTTON[mode].slice(); }

function mmss(s) { s = Math.max(0, Math.round(s || 0)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }
