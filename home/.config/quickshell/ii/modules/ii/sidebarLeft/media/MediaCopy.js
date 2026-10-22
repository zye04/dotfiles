.pragma library

const COPY = {
    t2i: ["Describe the image", "Subject, setting, light, lens — concrete beats clever.", "Woman in a red wool scarf on an old wooden pier, stormy sea behind her, overcast daylight, 35 mm photo", ["golden hour", "overcast", "35 mm", "shallow depth of field"]],
    edit: ["What should change?", "Describe the change. Ask to keep the rest the same.", "Make her coat dark green and add light rain", ["keep the face", "same lighting"]],
    i2v: ["Describe the motion", "What moves and how: action, pace, camera. The image already sets the look.", "She turns toward the camera and smiles, hair moving in the wind, slow push in", ["static camera", "slow push in", "natural movement", "slow motion"]]
};
const ROLE = { edit: "Will be edited", upscale: "Will be upscaled", i2v: "Will be animated", interp: "Will be smoothed" };
const BUTTON = { t2i: ["auto_awesome", "Create image"], edit: ["edit", "Edit image"], upscale: ["hd", "Upscale image"], region: ["brush", "Apply region edit"], i2v: ["movie", "Animate image"], interp: ["slow_motion_video", "Interpolate video"] };
const SHAPES = [["16:9", "landscape"], ["9:16", "portrait"], ["1:1", "square"], ["4:5", "portrait"]];

function appendSuggestion(text, word) {
    const t = text.replace(/[ ,.]*$/, "");
    return t.length ? t + ", " + word : word;
}
function buttonFor(mode, video) { return video && mode === "upscale" ? ["hd", "Upscale video"] : BUTTON[mode].slice(); }

function mmss(s) { s = Math.max(0, Math.round(s || 0)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }
