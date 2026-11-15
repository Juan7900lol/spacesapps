extends Node3D
## Astronauta sentado: la pose y las reacciones se hacen moviendo sus huesos por código.
## state: "normal", "warning", "solarFlare", "hypoxia" (los mismos escenarios de la app).
## g: fuerza G que siente (0 = flotando, 1 = peso normal, 4 = despegue).
## shake: vibración de la nave (0 a 1).

var state := "normal"
var g := 0.0
var shake := 0.0

var skel: Skeleton3D
var idx := {}
var to_skel: Basis          # pasa direcciones del astronauta al espacio del esqueleto
var phase := 0.0            # fase de la respiración
var rate := 0.25            # respiraciones por segundo
var slump := 0.0            # 1 = desplomado (poco oxígeno)
var hunch := 0.0            # 1 = encogido (radiación)
var worry := 0.0            # 1 = inquieto (advertencia)
var press := 0.0            # 1 = aplastado contra el asiento (fuerza G alta)
var floaty := 0.0           # 1 = sin peso, los brazos flotan
var t := 0.0

const RATES := {"normal": 0.25, "warning": 0.55, "solarFlare": 0.7, "hypoxia": 0.85}
const BONES := ["Hips","Spine","Spine1","Spine2","Neck","Head","HeadTop_End","LeftToeBase",
	"LeftShoulder","RightShoulder","LeftArm","RightArm","LeftForeArm","RightForeArm","LeftHand","RightHand",
	"LeftUpLeg","RightUpLeg","LeftLeg","RightLeg","LeftFoot","RightFoot"]

func setup(model: Node) -> void:
	skel = model.find_children("*", "Skeleton3D", true, false)[0]
	for ap in model.find_children("*", "AnimationPlayer", true, false):
		ap.stop()
	for b in BONES:
		var i := skel.find_bone("mixamorig_" + b)
		if i < 0:
			i = skel.find_bone("mixamorig:" + b)
		idx[b] = i
	var rel: Basis = (global_basis.inverse() * skel.global_basis).orthonormalized()
	to_skel = rel.inverse()

## Escala al astronauta a 'h' metros de alto (medido con sus huesos) y lo apoya en el piso.
func fit_height(model: Node3D, h: float) -> void:
	var top := _bone_pos("HeadTop_End")
	var foot := _bone_pos("LeftToeBase")
	model.scale *= h / maxf(top.y - foot.y, 0.001)
	var hips := _bone_pos("Hips")
	foot = _bone_pos("LeftToeBase")
	model.position -= Vector3(hips.x, foot.y, hips.z)

func _bone_pos(b: String) -> Vector3:
	var p := skel.global_transform * skel.get_bone_global_pose(idx[b]).origin
	return global_transform.affine_inverse() * p

func _process(dt: float) -> void:
	if skel == null:
		return
	t += dt
	var target_rate: float = RATES.get(state, 0.25)
	target_rate = maxf(target_rate, 0.25 + 0.15 * clampf(g - 1.0, 0.0, 3.0))
	rate = lerpf(rate, target_rate, dt * 1.5)
	phase += dt * rate * TAU
	slump = move_toward(slump, 1.0 if state == "hypoxia" else 0.0, dt * 0.35)
	hunch = move_toward(hunch, 1.0 if state == "solarFlare" else 0.0, dt * 2.0)
	worry = move_toward(worry, 1.0 if state == "warning" else 0.0, dt * 1.0)
	press = move_toward(press, clampf((g - 1.0) / 3.0, 0.0, 1.0), dt * 1.5)
	floaty = move_toward(floaty, 1.0 if g < 0.15 else 0.0, dt * 0.8)
	var fl: float = floaty * (1.0 - hunch) * (1.0 - slump)

	skel.reset_bone_poses()
	var X := Vector3.RIGHT
	var effort: float = maxf(maxf(worry, hunch), maxf(slump * 0.5, press))
	var breath: float = sin(phase) * lerpf(1.2, 3.5, effort)
	var jit: float = sin(t * 43.0) * shake

	# Torso y cabeza: respiración, desplome, encogerse, presión del despegue y vibración
	_rot("Spine", X, 4.0 + 18.0 * slump + 12.0 * hunch - 8.0 * press + jit * 0.5)
	_rot("Spine1", X, breath * -0.6 + 6.0 * hunch)
	_rot("Spine2", X, breath * -0.6)
	_rot("Neck", X, 22.0 * slump + 15.0 * hunch - 6.0 * press)
	_rot("Head", X, 18.0 * slump + 12.0 * hunch - 9.0 * press + jit * 1.2 + sin(t * 0.5) * 2.5 * fl)
	_rot("Head", Vector3.FORWARD, 14.0 * slump + sin(t * 0.37) * 3.0 * fl)
	_rot("Head", Vector3.UP, sin(t * 0.8) * 22.0 * worry * (1.0 - press))
	if hunch > 0.0:  # temblor
		_rot("Spine2", Vector3.UP, sin(t * 31.0) * 1.2 * hunch)
	_rot("LeftShoulder", Vector3.FORWARD, breath * 0.8 - 8.0 * hunch)
	_rot("RightShoulder", Vector3.FORWARD, -breath * 0.8 + 8.0 * hunch)

	# Piernas: sentado
	for s in ["Left", "Right"]:
		_aim(s + "UpLeg", s + "Leg", Vector3(0, -0.05 + 0.06 * fl, 1))
		_aim(s + "Leg", s + "Foot", Vector3(0, -1, 0.15 + 0.25 * fl))

	# Brazos: sobre los muslos / flotando sin peso / cruzados al encogerse / caídos al desmayarse
	for s in ["Left", "Right"]:
		var side := 1.0 if s == "Left" else -1.0
		var arm := Vector3(0.22 * side, -1, 0.3)
		var arm_float := Vector3(0.45 * side, -0.75, 0.7)
		var arm_hunch := Vector3(0.6 * side, -1, 0.6)
		var fore := Vector3(0.05 * side, -0.35, 1)
		var fore_float := Vector3(-0.15 * side, 0.25 + 0.12 * sin(t * 0.7 + side), 1)
		var fore_hunch := Vector3(-1.0 * side, 0.15, 0.4)
		var fore_slump := Vector3(0.1 * side, -1, 0.25)
		_aim(s + "Arm", s + "ForeArm", arm.lerp(arm_float, fl).lerp(arm_hunch, hunch))
		_aim(s + "ForeArm", s + "Hand", fore.lerp(fore_float, fl).lerp(fore_hunch, hunch).lerp(fore_slump, slump))

## Gira un hueso alrededor de un eje del astronauta (en grados).
func _rot(bone: String, axis: Vector3, deg: float) -> void:
	var i: int = idx.get(bone, -1)
	if i < 0 or is_zero_approx(deg):
		return
	_apply(i, Quaternion((to_skel * axis).normalized(), deg_to_rad(deg)))

## Apunta un hueso (de 'bone' hacia 'child') en una dirección del astronauta.
func _aim(bone: String, child: String, dir: Vector3) -> void:
	var i: int = idx.get(bone, -1)
	var c: int = idx.get(child, -1)
	if i < 0 or c < 0:
		return
	var d := (skel.get_bone_global_pose(c).origin - skel.get_bone_global_pose(i).origin).normalized()
	if d.is_zero_approx():
		return
	_apply(i, Quaternion(d, (to_skel * dir).normalized()))

func _apply(i: int, q: Quaternion) -> void:
	var p := skel.get_bone_parent(i)
	var pr := Quaternion.IDENTITY if p < 0 else skel.get_bone_global_pose(p).basis.get_rotation_quaternion()
	skel.set_bone_pose_rotation(i, (pr.inverse() * q * pr * skel.get_bone_pose_rotation(i)).normalized())
