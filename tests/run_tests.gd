extends SceneTree
## Headless test runner. Discovers tests/test_*.gd; each file extends TestCase
## and defines async-capable `test_*` methods. Exit code = number of failures.
## Usage: Godot --headless -s tests/run_tests.gd [-- filter]

var failures := 0
var passes := 0

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]
	var dir := DirAccess.open("res://tests")
	var files := []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		for m in script.get_script_method_list():
			var mname: String = m.name
			if not mname.begins_with("test_"):
				continue
			if filter != "" and not (f + ":" + mname).contains(filter):
				continue
			var tc: TestCase = script.new()
			tc.tree = self
			await tc.setup()
			await tc.call(mname)
			await tc.teardown()
			var label := "%s:%s" % [f, mname]
			if tc.errors.is_empty():
				passes += 1
				print("PASS ", label)
			else:
				failures += 1
				print("FAIL ", label)
				for e in tc.errors:
					print("    ", e)
			tc.free()
	print("\n%d passed, %d failed" % [passes, failures])
	quit(failures)
