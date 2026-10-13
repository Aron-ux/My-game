-- Run from the repository root: aseprite --batch --script scripts/tools/import_mechanic_art.lua
-- Imagegen owns the drawings; this import only slices, registers, resizes and quantizes them.
local source = "design/mechanic-rework-20261013/source/"
local pc = app.pixelColor
local function round(n) return math.floor(n + 0.5) end

local function binary_alpha(image)
  for pixel in image:pixels() do
    local c = pixel()
    pixel(pc.rgbaA(c) >= 128 and pc.rgba(pc.rgbaR(c), pc.rgbaG(c), pc.rgbaB(c), 255) or 0)
  end
end

local function registered(image, crop, factor, pivot, anchor, size)
  local part = Image(image, Rectangle(table.unpack(crop)))
  part:resize(round(part.width * factor), round(part.height * factor))
  binary_alpha(part)
  local x = round(anchor[1]) - round((pivot[1] - crop[1]) * factor)
  local y = round(anchor[2]) - round((pivot[2] - crop[2]) * factor)
  assert(x >= 0 and y >= 0 and x + part.width <= size and y + part.height <= size, "clipped frame")
  local result = Image(size, size)
  result:drawImage(part, Point(x, y))
  assert(not result:isEmpty(), "empty frame")
  return result
end

local function animation(frames, fps, quantize)
  local sprite = Sprite(frames[1].width, frames[1].height)
  for i, frame in ipairs(frames) do
    if i > 1 then sprite:newEmptyFrame() end
    sprite:newCel(sprite.layers[1], i, frame, Point(0, 0))
    sprite.frames[i].duration = 1 / fps
  end
  if quantize then
    app.activeSprite = sprite
    app.command.ColorQuantization { ui=false, maxColors=64, withAlpha=true }
    app.command.ChangePixelFormat { ui=false, format="indexed", dithering="none" }
  end
  return sprite
end

local function render(sprite, frame)
  local result = Image(sprite.width, sprite.height)
  result:drawSprite(sprite, frame, Point(0, 0))
  return result
end

local actor = Image { fromFile=source .. "character-animations.png" }
assert(actor.width == 1254 and actor.height == 1254, "review new source registration before importing")
-- Reviewed bounds and hip/ground anchors; the generated sheet is not an exact uniform grid.
local poses = {
  {82,49,148,265,170}, {391,53,157,261,483}, {699,50,171,264,796}, {1014,49,151,265,1109},
  {63,350,210,269,184}, {379,360,209,259,498}, {679,356,212,263,811}, {997,350,208,263,1124},
  {52,657,226,271,184}, {373,665,219,263,498}, {681,663,217,266,811}, {995,658,209,270,1124},
  {80,989,167,236,174}, {379,975,216,250,488}, {687,973,231,252,801}, {1023,958,154,267,1117}
}
local actor_frames = {}
for _, p in ipairs(poses) do
  table.insert(actor_frames, registered(actor, {p[1],p[2],p[3],p[4]}, 0.3,
    {p[5],p[2]+p[4]}, {48,88}, 96))
end
local all = animation(actor_frames, 10, true)
for i=1,#actor_frames do actor_frames[i] = render(all, i) end
all:close()
local player_dir = "assets/players/mechanic/"
for _, clip in ipairs({{"idle",1,4,5}, {"run",5,12,11}, {"command",13,16,12}}) do
  local frames = {}
  for i=clip[2],clip[3] do table.insert(frames, actor_frames[i]) end
  local sprite = animation(frames, clip[4], false)
  local tag = sprite:newTag(1, #frames)
  tag.name = "mechanic-" .. clip[1]
  sprite:saveAs(player_dir .. tag.name .. ".aseprite")
  local sheet = Image(#frames * 96, 96)
  for i, frame in ipairs(frames) do sheet:drawImage(frame, Point((i-1)*96,0)) end
  sheet:saveAs(player_dir .. tag.name .. ".png")
  sprite:close()
end
actor_frames[1]:saveAs(player_dir .. "mechanic-standing.png")
local portrait = Image { fromFile=source .. "portrait.png" }
binary_alpha(portrait)
local face_bounds = portrait:shrinkBounds()
portrait = Image(portrait, face_bounds)
portrait:resize(round(portrait.width * 62 / portrait.height),62)
local head = Image(64,64)
head:drawImage(portrait, Point(math.floor((64-portrait.width)/2),1))
local icon = animation({head}, 1, true)
icon:saveAs(player_dir .. "mechanic-portrait.aseprite")
head = render(icon,1)
head:resize(128,128)
head:saveAs("assets/UI/facility/机械师.png")
head = render(icon,1)
head:resize(36,36)
head:saveAs("assets/UI/facility/机械师head.png")
icon:close()

local function equipment(name, cols, rows, factor, anchor, pivot_y)
  local image = Image { fromFile=source .. name .. ".png" }
  binary_alpha(image)
  local frames = {}
  for row=0,rows-1 do
    for col=0,cols-1 do
      local x, y = round(col*image.width/cols), round(row*image.height/rows)
      local w, h = round((col+1)*image.width/cols)-x, round((row+1)*image.height/rows)-y
      local cell = Image(image, Rectangle(x,y,w,h))
      local bounds = cell:shrinkBounds()
      local pivot = {w/2, pivot_y or bounds.y+bounds.height}
      frames[#frames+1] = registered(cell, {bounds.x,bounds.y,bounds.width,bounds.height}, factor,
        pivot, anchor, 64)
    end
  end
  return frames
end

local function save_effect(name, frames, fps, output_size)
  local sprite = animation(frames, fps, true)
  sprite:saveAs("effects/mechanic/" .. name .. "/" .. name .. ".aseprite")
  local exported = {}
  for i=1,#frames do
    local frame = render(sprite, i)
    frame:resize(output_size, output_size)
    frame:saveAs("effects/mechanic/" .. name .. "/" .. i .. ".png")
    exported[i] = frame
  end
  sprite:close()
  return exported
end

save_effect("tulip_turret", equipment("tulip_turret",3,1,0.078,{31,56}), 9,256)
save_effect("heavy_cannon", equipment("heavy_cannon",3,1,0.078,{32,56}), 9,256)
save_effect("field_tower", equipment("field_tower",3,1,0.078,{32,59}), 9,256)
save_effect("spider", equipment("spider",2,2,0.09,{32,46}), 10,128)
save_effect("drone", equipment("drone",2,2,0.105,{32,52},530), 9,256)
local blast = equipment("ult_explosion",4,2,0.135,{32,32},222)
-- Skip the redundant last smoke ring, retaining the final disappearing embers.
local ultimate = {blast[1],blast[2],blast[3],blast[4],blast[5],blast[6],blast[8]}
save_effect("ult_explosion", ultimate, 12,256)
local mine = equipment("mine",2,1,0.065,{32,48})
for _, i in ipairs({1,3,4,5,6,8}) do mine[#mine+1] = blast[i] end
save_effect("mine", mine, 12,256)
save_effect("ult_warning", equipment("ult_warning",3,1,0.085,{32,32},347), 6,256)
print("MECHANIC_ART_IMPORT_OK")
