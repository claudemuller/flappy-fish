package flappyfish

import "core:fmt"
import "core:math/rand"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

SCREEN_WIDTH :: 1024
SCREEN_HEIGHT :: 768
GRAVITY :: 25
JUMP_STRENGTH :: 600
SPEED :: 50
BLOCK_WIDTH :: 32

Player :: struct {
	pos_px: rl.Vector2,
	vel:    rl.Vector2,
	size:   rl.Vector2,
	colour: rl.Color,
}

BlockType :: enum {
	BLANK,
	WALL,
}

level: [32 * 24]BlockType
player: Player

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

	gen_level()
}

process_input :: proc() {
	if rl.IsKeyPressed(.SPACE) do player.vel += {0, -JUMP_STRENGTH}
}

update :: proc() {
	dt := rl.GetFrameTime()

	player.vel.y += GRAVITY
	// if player.vel.y >= TERMINAL_VELOCITY {
	// 	player.vel.y = TERMINAL_VELOCITY
	// }
	player.pos_px += player.vel * dt


}

render :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground({50, 51, 83, 255})

	// rl.BeginMode2D(camera)

	// Draw level
	for b, i in level {
		grid_x := i32(i % (SCREEN_WIDTH / BLOCK_WIDTH))
		grid_y := i32(i / (SCREEN_WIDTH / BLOCK_WIDTH))
		x := grid_x * BLOCK_WIDTH
		y := grid_y * BLOCK_WIDTH

		if b == .WALL {
			rl.DrawRectangle(x, y, BLOCK_WIDTH, BLOCK_WIDTH, {77, 101, 180, 255})
		} else {
			rl.DrawRectangle(x, y, BLOCK_WIDTH, BLOCK_WIDTH, {0, 101, 180, 255})
		}

		rl.DrawRectangleLines(x, y, BLOCK_WIDTH, BLOCK_WIDTH, rl.DARKGRAY)
		// rl.DrawText(fmt.ctprintf("%d:%d", grid_x, grid_y), x, y, 20, rl.BLACK)
	}

	// Draw player
	rl.DrawRectangleV(player.pos_px, player.size, player.colour)

	// rl.EndMode2D()

	draw_ui()

	rl.EndDrawing()
}

draw_ui :: proc() {
	rl.DrawText("Score: ", 20, 20, 20, rl.WHITE)
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
