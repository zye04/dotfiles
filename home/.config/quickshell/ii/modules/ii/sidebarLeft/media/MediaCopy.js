.pragma library

const COPY = {
    t2i: ["Describe the image", "Subject, setting, light, lens — concrete beats clever.", "Woman in a red wool scarf on an old wooden pier, stormy sea behind her, overcast daylight, 35 mm photo", ["golden hour", "overcast", "35 mm", "shallow depth of field"]],
    edit: ["What should change?", "Say only the change; everything else stays.", "Make her coat dark green and add light rain", ["keep the face", "same lighting"]],
    t2v: ["Describe the scene and the motion", "Who and where, then one continuous action. Camera moves count.", "Woman in a red scarf walks along a wooden pier toward the camera, wind in her hair, waves hitting the posts, handheld", ["handheld", "slow push in", "wind"]],
    i2v: ["Describe the motion", "The image sets the look; say what moves and how.", "She turns from the sea and walks toward the camera, hair and scarf blowing in the wind", ["handheld", "slow push in", "natural pace"]],
    long: ["Scene and first 5 s", "Who, where and the look hold for the whole clip. End with what happens first.", "Young woman, red scarf, black coat, wooden pier, stormy sea, overcast, handheld 35 mm. She turns from the sea and starts walking toward the camera.", ["handheld", "overcast"]]
};
const THEN = ["then she pulls the scarf tighter, still walking", "then glances back at a crashing wave", "then stops and smiles into the lens", "then…", "then…"];
const CAMERAS = ["", "static", "pan", "push_in", "handheld"];
const CAMERA_LABEL = { "": "Camera", static: "Static", pan: "Pan", push_in: "Push in", handheld: "Handheld" };
const ROLE = { edit: "Will be edited", upscale: "Will be upscaled", i2v: "First frame of the video", long: "First frame of the video", enhance: "Will be enhanced" };
const BUTTON = { t2i: ["auto_awesome", "Create image"], edit: ["edit", "Edit image"], upscale: ["hd", "Upscale image"], t2v: ["videocam", "Create video"], i2v: ["movie", "Animate image"], long: ["movie", "Animate image"], enhance: ["auto_fix_high", "Enhance video"] };
const QUALITY_HINT_VIDEO = { draft: "~2 min / 5 s", balanced: "~4 min / 5 s", realistic: "~14 min / 5 s" };
const QUALITY_HINT_IMAGE = { draft: "~8 s", balanced: "~12 s", realistic: "~20 s" };
const SHAPES = [["16:9", "landscape"], ["9:16", "portrait"], ["1:1", "square"], ["4:5", "portrait"]];
const LENGTHS = [[5, "one shot"], [10, "2 beats"], [20, "4 beats"], [30, "6 beats"]];

function appendSuggestion(text, word) {
    const t = text.replace(/[ ,.]*$/, "");
    return t.length ? t + ", " + word : word;
}
function buttonFor(mode, hasSource) {
    const b = BUTTON[mode].slice();
    if (mode === "long" && !hasSource) b[1] = "Create video";
    return b;
}
