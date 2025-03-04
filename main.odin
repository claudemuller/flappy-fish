package flappyfish

import "core:fmt"
import "core:math/rand"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

FONT_SIZE :: 30

SCREEN_WIDTH :: 1024
SCREEN_HEIGHT :: 768
BLOCK_WIDTH :: 32
CAMERA_SHAKE_MAGNITUDE :: 5.0
CAMERA_SHAKE_DURATION :: 15
MENU_TIMEOUT :: 1

GRAVITY :: 900
JUMP_STRENGTH :: 500
SPEED :: 200

Player :: struct {
	pos_px: rl.Vector2,
	vel:    rl.Vector2,
	size:   rl.Vector2,
	colour: rl.Color,
}

Level :: struct {
	speed:             f32,
	length_multiplier: i32,
	num_walls:         i32,
	hole_size:         i32,
}

BlockType :: enum {
	BLANK,
	WALL,
}

GameState :: enum {
	MAIN_MENU,
	WIN_SCREEN,
	GAME_OVER,
	LEVEL1,
	LEVEL2,
	LEVEL3,
}

game_state := GameState.MAIN_MENU
world: []BlockType
levels: map[GameState]Level
camera: rl.Camera2D
camera_shake_duration: f32
menu_timer: f32
player: Player
score: i32

main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Flappy Fish")
	rl.SetTargetFPS(60)
	rl.SetExitKey(.ESCAPE)

	setup()

	for !rl.WindowShouldClose() {
		process_input()
		update()
		render()
	}
}

setup :: proc() {
	pw: f32 = BLOCK_WIDTH
	ph: f32 = BLOCK_WIDTH
	player = {
		pos_px = {BLOCK_WIDTH * 2, SCREEN_HEIGHT / 2 - ph / 2},
		size   = {pw, ph},
		vel    = {SPEED, 0},
		colour = {245, 125, 74, 255},
	}

	camera = {
		offset = {SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2},
		zoom   = 1,
		target = player.pos_px,
	}

	levels[.LEVEL1] = Level {
		speed             = 1,
		length_multiplier = 2,
		num_walls         = 5,
		hole_size         = 7,
	}
	levels[.LEVEL2] = Level {
		speed             = 2,
		length_multiplier = 4,
		num_walls         = 8,
		hole_size         = 5,
	}
	levels[.LEVEL3] = Level {
		speed             = 3,
		length_multiplier = 6,
		num_walls         = 12,
		hole_size         = 3,
	}

	load_level(.LEVEL1)
}

process_input :: proc() {
	if rl.IsKeyPressed(.SPACE) {
		#partial switch game_state {
		case .MAIN_MENU:
			game_state = .LEVEL1
			load_level(.LEVEL1)

		case .GAME_OVER:
			game_state = .LEVEL1
			load_level(.LEVEL1)

		case:
			player.vel += {0, -JUMP_STRENGTH}
		}
	}
}

update :: proc() {
	if camera_shake_duration > 0 {
		camera.offset.x += f32(rl.GetRandomValue(-CAMERA_SHAKE_MAGNITUDE, CAMERA_SHAKE_MAGNITUDE))
		camera.offset.y += f32(rl.GetRandomValue(-CAMERA_SHAKE_MAGNITUDE, CAMERA_SHAKE_MAGNITUDE))
		camera_shake_duration -= 1
	} else {
		camera.offset = {SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2}
	}

	if game_state == .MAIN_MENU || game_state == .GAME_OVER {
		return
	}

	dt := rl.GetFrameTime()

	if menu_timer > 0 {
		menu_timer -= dt
		return
	}

	camera.target = clamp_camera(player.pos_px)

	player.vel.y += GRAVITY * dt
	player.pos_px += player.vel * dt

	check_collisions()
}

render :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground({50, 51, 83, 255})

	if game_state >= .GAME_OVER {
		if menu_timer > 0 {
			draw_level_screen()
		} else {
			draw_world()
		}
	}

	#partial switch game_state {
	case .MAIN_MENU:
		draw_main_menu()

	case .GAME_OVER:
		draw_game_over()

	case .WIN_SCREEN:
		draw_win_screen()

	case:
		draw_game_ui()
	}

	rl.EndDrawing()
}

draw_world :: proc() {
	rl.BeginMode2D(camera)

	height_in_blocks := SCREEN_HEIGHT / BLOCK_WIDTH
	width_in_blocks := len(world) / height_in_blocks

	// Draw level
	for b, i in world {
		grid_x := i32(i % width_in_blocks)
		grid_y := i32(i / width_in_blocks)
		x := grid_x * BLOCK_WIDTH
		y := grid_y * BLOCK_WIDTH

		if b == .WALL {
			rl.DrawRectangle(x, y, BLOCK_WIDTH, BLOCK_WIDTH, {77, 101, 180, 255})
		}

		rl.DrawRectangleLines(x, y, BLOCK_WIDTH, BLOCK_WIDTH, rl.DARKGRAY)
		// rl.DrawText(fmt.ctprintf("%d:%d", grid_x, grid_y), x, y, 20, rl.BLACK)
	}

	// Draw player
	rl.DrawRectangleV(player.pos_px, player.size, player.colour)

	rl.EndMode2D()
}

load_level :: proc(level: GameState) {
	player.pos_px = {BLOCK_WIDTH * 2, SCREEN_HEIGHT / 2 - player.size.y / 2}
	player.vel = {SPEED, 0}
	menu_timer = MENU_TIMEOUT

	gen_level(levels[level])
}

check_collisions :: proc() {
	height_in_blocks := SCREEN_HEIGHT / BLOCK_WIDTH
	width_in_blocks := len(world) / height_in_blocks

	if player.pos_px.x > f32(width_in_blocks * BLOCK_WIDTH) - player.size.x {
		if game_state == .LEVEL3 {
			game_state = .WIN_SCREEN
			return
		}

		load_level(game_state + GameState(1))
		return
	}

	if player.pos_px.x < 0 ||
	   player.pos_px.y < 0 ||
	   player.pos_px.y > f32(height_in_blocks * BLOCK_WIDTH) - player.size.y {
		camera_shake_duration = CAMERA_SHAKE_DURATION
		game_state = .GAME_OVER
		return
	}

	// TODO:(lukefilewalker) don't iterate over all blocks just for wall blocks
	for block, i in world {
		if block == .WALL {
			grid_x := i32(i % width_in_blocks)
			grid_y := i32(i / width_in_blocks)
			x := grid_x * BLOCK_WIDTH
			y := grid_y * BLOCK_WIDTH
			if rl.CheckCollisionRecs(
				rl.Rectangle{player.pos_px.x, player.pos_px.y, player.size.x, player.size.y},
				rl.Rectangle{f32(x), f32(y), BLOCK_WIDTH, BLOCK_WIDTH},
			) {
				camera_shake_duration = CAMERA_SHAKE_DURATION
				game_state = .GAME_OVER
			}
		}
	}
}

gen_level :: proc(level: Level) {
	width_in_blocks := SCREEN_WIDTH / BLOCK_WIDTH * level.length_multiplier
	height_in_blocks: i32 = SCREEN_HEIGHT / BLOCK_WIDTH
	world = make([]BlockType, width_in_blocks * height_in_blocks)

	for i in 0 ..< level.num_walls {
		hole_size := level.hole_size
		hole_y := rand.int31_max(height_in_blocks - hole_size * 2) + hole_size
		x := rand.int31_max(width_in_blocks - 10) + 10

		for world[x] == .WALL {
			x = rand.int31_max(width_in_blocks)
		}

		for y in 0 ..< height_in_blocks {
			if i32(y) == hole_y {
				if hole_size > 1 {
					hole_y += 1
				}
				hole_size -= 1
				continue
			}
			world[i32(y) * width_in_blocks + x] = .WALL
		}
	}
}

draw_level_screen :: proc() {
	str := fmt.ctprintf("Level %d", int(game_state) - 2)
	w := rl.MeasureText(str, FONT_SIZE)
	rl.DrawText(
		str,
		SCREEN_WIDTH / 2 - w / 2,
		SCREEN_HEIGHT / 2 - FONT_SIZE / 2,
		FONT_SIZE,
		rl.RAYWHITE,
	)
}

draw_game_ui :: proc() {
	rl.DrawText(fmt.ctprintf("Score: %d", score), 20, 20, 20, rl.RAYWHITE)
	rl.DrawText(
		fmt.ctprintf("Level: %d", int(game_state) - 2),
		SCREEN_WIDTH - 100,
		20,
		20,
		rl.RAYWHITE,
	)
}

draw_main_menu :: proc() {
	str := fmt.ctprint("Press <space> to start playing")
	w := rl.MeasureText(str, FONT_SIZE)
	rl.DrawText(
		str,
		SCREEN_WIDTH / 2 - w / 2,
		SCREEN_HEIGHT / 2 - FONT_SIZE / 2,
		FONT_SIZE,
		rl.RAYWHITE,
	)
}

draw_game_over :: proc() {
	header_size: i32 = FONT_SIZE * 2
	str1 := fmt.ctprint("Game Over")
	w1 := rl.MeasureText(str1, header_size)
	str2 := fmt.ctprintf("Your score: %d", score)
	w2 := rl.MeasureText(str2, FONT_SIZE)
	str3 := fmt.ctprint("Press <space> to start playing")
	w3 := rl.MeasureText(str3, FONT_SIZE)
	str4 := fmt.ctprint("Press <escape> to quit")
	w4 := rl.MeasureText(str4, FONT_SIZE)
	total_height: i32 = FONT_SIZE * 4 + 10
	rl.DrawText(
		str1,
		SCREEN_WIDTH / 2 - w1 / 2,
		SCREEN_HEIGHT / 2 - total_height + header_size / 2,
		header_size,
		rl.RAYWHITE,
	)
	rl.DrawText(
		str2,
		SCREEN_WIDTH / 2 - w2 / 2,
		SCREEN_HEIGHT / 2 - total_height + header_size + FONT_SIZE,
		FONT_SIZE,
		rl.RAYWHITE,
	)
	rl.DrawText(
		str3,
		SCREEN_WIDTH / 2 - w3 / 2,
		SCREEN_HEIGHT / 2 - total_height + header_size + FONT_SIZE * 2 + 40,
		FONT_SIZE,
		rl.RAYWHITE,
	)
	rl.DrawText(
		str4,
		SCREEN_WIDTH / 2 - w4 / 2,
		SCREEN_HEIGHT / 2 - total_height + header_size + FONT_SIZE * 3 + 40,
		FONT_SIZE,
		rl.RAYWHITE,
	)
}

draw_win_screen :: proc() {
	str := fmt.ctprint("You win with a score of %d", score)
	w := rl.MeasureText(str, FONT_SIZE)
	rl.DrawText(
		str,
		SCREEN_WIDTH / 2 - w / 2,
		SCREEN_HEIGHT / 2 - FONT_SIZE / 2,
		FONT_SIZE,
		rl.RAYWHITE,
	)
}

clamp_camera :: proc(vec: rl.Vector2) -> rl.Vector2 {
	height_in_blocks := SCREEN_HEIGHT / BLOCK_WIDTH
	width_in_blocks := len(world) / height_in_blocks

	half_window_width := SCREEN_WIDTH / 2.0 / camera.zoom
	half_window_height := SCREEN_HEIGHT / 2.0 / camera.zoom

	minX: f32 = half_window_width
	minY: f32 = half_window_height

	maxX: f32 = f32(width_in_blocks * BLOCK_WIDTH) - half_window_width
	maxY: f32 = SCREEN_HEIGHT - half_window_height

	res_vec := vec

	if (res_vec.x < minX) do res_vec.x = minX
	if (res_vec.y < minY) do res_vec.y = minY
	if (res_vec.x > maxX) do res_vec.x = maxX
	if (res_vec.y > maxY) do res_vec.y = maxY

	return res_vec
}
