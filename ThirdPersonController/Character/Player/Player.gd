extends KinematicBody

# ---对象属性---

# 移动速度
export var moveSpeed : float = 10
# 跳跃速度
export var jumpAcceleration : float = 200
# 下落加速度
export var fallAcceleration : float = 9.8
# 线速度
var linearVelocity : Vector3 = Vector3.ZERO
# 鼠标灵敏度
export var mouseSensitivity : float = 0.05
# 鼠标最大移动速度
export var mouseMoveMaxSpeed : float = 10
# 最小俯仰角
export var cameraMinPitch : float = -45
# 最大俯仰角
export var cameraMaxPitch : float = 90
# 角色转身速度
export var playerRotSpeed : float = 0.2
# 角色在斜面上滑动的加速度
export var slipAcceleration : float = 1

# ---组件引用---

# Mesh
onready var meshes = $Meshes
# 弹簧臂
onready var springarm = $SpringArm
# 摄像机
onready var camera = $SpringArm/Camera

# ---控制缓存---

# 是否应该旋转弹簧臂
var shouldCameraMove : bool = false
# 物体坐标系二维平面上鼠标运动方向 向上向左为负 向下向右为正
var mouseMoveSpeed = Vector2(0,0)
# y 方向上的加速度
var yAcceleration = 0

# ---控制参数---

# y 方向加速度的缩放比例
# 为了让 fallAcceleration 保持 9.8 不变，符合常识
var yAccelerationScale : float = 10

# ---事件---

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event) -> void:
	
	# 如果获得”鼠标正在运动“事件
	if event is InputEventMouseMotion:
		# 如果得到鼠标相对于最后一帧的位移不是 0 而是 Vector2，说明鼠标相对于最后一帧移动了
		if typeof(event.relative) == TYPE_VECTOR2:
			# 应该旋转摄像机
			shouldCameraMove = true
			# 获得鼠标在一帧内的移动量
			mouseMoveSpeed = event.relative
	
	# 如果按退出键
	if Input.is_action_just_released("ui_cancel"):
		print("cancel")
		# 在鼠标隐藏和固定之间切换
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# ---自定义函数---

# 玩家运动
func playerMove(deltaTime):
	
	# ---水平方向---
	
	# 控制缓存 移动方向
	var direction = Vector3.ZERO
	
	# 获取摄像机地前后左右方向
	# 注意 xyz 坐标系的方向
	if Input.is_action_pressed("move_right"):
		direction += camera.get_global_transform().basis.x
	if Input.is_action_pressed("move_left"):
		direction -= camera.get_global_transform().basis.x
	if Input.is_action_pressed("move_up"):
		direction -= camera.get_global_transform().basis.z
	if Input.is_action_pressed("move_down"):
		direction += camera.get_global_transform().basis.z
			
	# 水平移动方向单位化
	if direction != Vector3.ZERO:
		direction = direction.normalized()
	
	# 水平线速度
	linearVelocity = direction * moveSpeed
	
	# ---竖直方向---
	
	# 在地面上，判断是否跳跃
	if is_on_floor():
		# 在地面起跳，跳跃加速度
		if Input.is_action_pressed("jump"):
			yAcceleration = jumpAcceleration
		# 在地面上没有起跳，那么向下的加速度为斜面滑动加速度
		else:
			yAcceleration = slipAcceleration
	# 不在地面上，重力加速度
	else:
		yAcceleration -= fallAcceleration
	
	# 应用 y 方向加速度
	linearVelocity += Vector3.UP * yAcceleration / yAccelerationScale
	# 角色移动
	linearVelocity = move_and_slide(linearVelocity, Vector3.UP)

# 摄像机旋转
func cameraRotate(deltaTime):
	
	# 如果需要旋转摄像机
	if shouldCameraMove:
		# 已经开始旋转摄像机
		shouldCameraMove = false
		# 旋转摄像机
		camera.rotate_x(-lerp(0, mouseSensitivity, mouseMoveSpeed.y/mouseMoveMaxSpeed))
		# 钳制
		camera.rotation_degrees.x = clamp(camera.rotation_degrees.x,cameraMinPitch,cameraMaxPitch)
		# 旋转弹簧臂
		springarm.rotate_y(-lerp(0, mouseSensitivity, mouseMoveSpeed.x/mouseMoveMaxSpeed))

# 玩家模型旋转
func meshesRotate(deltaTime):
	# meshes 前方向
	var meshesForwardVector = meshes.get_global_transform().basis.z
	# 弹簧臂 前方向 由于我弹簧臂摆放的设置，这个获得的前方向和期望的前方向是相反的
	var springarmForwardVector = -springarm.get_global_transform().basis.z
	# meshes 前方向 和 弹簧臂 前方向 之间的夹角
	var angle = meshesForwardVector.angle_to(springarmForwardVector)
	# 从 meshes 前方向 到 弹簧臂 前方向 的向量
	var deltaVector = springarmForwardVector - meshesForwardVector
	
	# rotate_x 增加的方向是逆时针方向
	# 如果从 meshes 前方向 到 弹簧臂 前方向 是顺时针方向，就把 angle 设为负
	if deltaVector.dot(meshes.get_global_transform().basis.x) < 0:
		angle = -angle
	
	# 应用角色转身速度
	angle *= playerRotSpeed
	
	# meshes 旋转
	meshes.rotate_y(angle)

# ---虚函数实现--- 

# 固定帧率执行
func _physics_process(deltaTime):
	
	playerMove(deltaTime)
	cameraRotate(deltaTime)
	meshesRotate(deltaTime)
