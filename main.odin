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

GRAVITY :: 25
JUMP_STRENGTH :: 800
SPEED :: 200

Player :: struct {
	pos_px: rl.Vector2,
	vel:    rl.Vector2,
	size:   rl.Vector2,
	colour: rl.Color,
}

Level :: struct {
	speed:        f32,
	level_length: f32,
	num_walls:    i32,
}

BlockType :: enum {
	BLANK,
	WALL,
}

GameState :: enum {
	MAIN_MENU,
	GAME_OVER,
	LEVEL1,
	LEVEL2,
	LEVEL3,
}

game_state := GameState.MAIN_MENU
level: [32 * 24]BlockType
camera: rl.Camera2D
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
	camera = {
		offset = {SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2},
		zoom   = 1,
	}

	reset_level()

	gen_level()
}

process_input :: proc() {
	if rl.IsKeyPressed(.SPACE) {
		#partial switch game_state {
		case .MAIN_MENU:
			reset_level()

		case .GAME_OVER:
			reset_level()

		case:
			player.vel += {0, -JUMP_STRENGTH}
		}
	}
}

update :: proc() {
	if game_state == .MAIN_MENU || game_state == .GAME_OVER {
		return
	}

	camera.target = clamp_camera(player.pos_px)

	dt := rl.GetFrameTime()

	player.vel.y += GRAVITY
	// if player.vel.y >= TERMINAL_VELOCITY {
	// 	player.vel.y = TERMINAL_VELOCITY
	// }
	player.pos_px += player.vel * dt

	check_collisions()
}

render :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground({50, 51, 83, 255})

	rl.BeginMode2D(camera)

	if game_state >= .GAME_OVER {
		// Draw level
		for b, i in level {
			grid_x := i32(i % (SCREEN_WIDTH / BLOCK_WIDTH))
			grid_y := i32(i / (SCREEN_WIDTH / BLOCK_WIDTH))
			x := grid_x * BLOCK_WIDTH
			y := grid_y * BLOCK_WIDTH

			if b == .WALL {
				rl.DrawRectangle(x, y, BLOCK_WIDTH, BLOCK_WIDTH, {77, 101, 180, 255})
			} else {
				// rl.DrawRectangle(x, y, BLOCK_WIDTH, BLOCK_WIDTH, {0, 101, 180, 255})
			}

			rl.DrawRectangleLines(x, y, BLOCK_WIDTH, BLOCK_WIDTH, rl.DARKGRAY)
			// rl.DrawText(fmt.ctprintf("%d:%d", grid_x, grid_y), x, y, 20, rl.BLACK)
		}

		// Draw player
		rl.DrawRectangleV(player.pos_px, player.size, player.colour)
	}

	rl.EndMode2D()

	#partial switch game_state {
	case .MAIN_MENU:
		draw_main_menu()

	case .GAME_OVER:
		draw_game_over()

	case:
		draw_ui()
	}

	rl.EndDrawing()
}

reset_level :: proc() {
	pw: f32 = BLOCK_WIDTH
	ph: f32 = BLOCK_WIDTH
	player = {
		pos_px = {BLOCK_WIDTH * 2, SCREEN_HEIGHT / 2 - ph / 2},
		size   = {pw, ph},
		vel    = {SPEED, 0},
		colour = {245, 125, 74, 255},
	}

	camera.target = player.pos_px

	level1 := Level {
		speed        = 1,
		level_length = 2,
		num_walls    = 5,
	}

	game_state = .LEVEL1
}

check_collisions :: proc() {
	if player.pos_px.x < 0 ||
	   player.pos_px.x > SCREEN_WIDTH - player.size.x ||
	   player.pos_px.y < 0 ||
	   player.pos_px.y > SCREEN_HEIGHT - player.size.y {
		game_state = .GAME_OVER
		return
	}

	// TODO:(lukefilewalker) don't iterate over all blocks just for wall blocks
	for block, i in level {
		if block == .WALL {
			grid_x := f32(i % (SCREEN_WIDTH / BLOCK_WIDTH))
			grid_y := f32(i / (SCREEN_WIDTH / BLOCK_WIDTH))
			x := grid_x * BLOCK_WIDTH
			y := grid_y * BLOCK_WIDTH
			if rl.CheckCollisionRecs(
				rl.Rectangle{player.pos_px.x, player.pos_px.y, player.size.x, player.size.y},
				rl.Rectangle{x, y, BLOCK_WIDTH, BLOCK_WIDTH},
			) {
				game_state = .GAME_OVER
			}
		}
	}
}

gen_level :: proc() {
	level_len := 2
	// TODO:(lukefilewalker) will increase as teh leëls get harder
	width_in_blocks: i32 = SCREEN_WIDTH / BLOCK_WIDTH // * level_len
	num_walls_in_level := 3
	// TODO:(lukefilewalker) will reduce as teh leëls get harder
	height_in_blocks: i32 = SCREEN_HEIGHT / BLOCK_WIDTH // * level_len

	for i in 0 ..< num_walls_in_level {
		hole_size: i32 = 5
		x := rand.int31_max(width_in_blocks)
		hole_y := rand.int31_max(height_in_blocks - (hole_size * 2)) + hole_size

		for level[x] == .WALL {
			x = rand.int31_max(width_in_blocks)
		}

		for y in 0 ..< SCREEN_HEIGHT / BLOCK_WIDTH {
			if i32(y) == hole_y {
				if hole_size > 1 {
					hole_y += 1
				}
				hole_size -= 1
				continue
			}
			level[i32(y) * (SCREEN_WIDTH / BLOCK_WIDTH) + x] = .WALL
		}
	}
}

draw_ui :: proc() {
	rl.DrawText(fmt.ctprintf("Score: %d", score), 20, 20, 20, rl.RAYWHITE)
}

draw_main_menu :: proc() {
	play_str := fmt.ctprint("Press <space> to start playing")
	str_w := rl.MeasureText(play_str, FONT_SIZE)
	rl.DrawText(
		play_str,
		SCREEN_WIDTH / 2 - str_w / 2,
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

clamp_camera :: proc(vec: rl.Vector2) -> rl.Vector2 {
	half_window_width := SCREEN_WIDTH / 2.0 / camera.zoom
	half_window_height := SCREEN_HEIGHT / 2.0 / camera.zoom
	minX: f32 = half_window_width
	minY: f32 = half_window_height
	maxX: f32 = SCREEN_WIDTH - half_window_width
	maxY: f32 = SCREEN_HEIGHT - half_window_height

	res_vec := vec

	if (res_vec.x < minX) do res_vec.x = minX
	if (res_vec.y < minY) do res_vec.y = minY
	if (res_vec.x > maxX) do res_vec.x = maxX
	if (res_vec.y > maxY) do res_vec.y = maxY

	return res_vec
}
