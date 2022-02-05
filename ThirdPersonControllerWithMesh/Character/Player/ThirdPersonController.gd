extends CharacterBody3D

# ---对象属性---

# ---运动参数---

# 移动速度
@export var moveSpeed : float = 5
# 跳跃速度
@export var jumpAcceleration : float = 200
# 下落加速度
@export var fallAcceleration : float = 9.8
# 角色转身速度
@export var playerRotSpeed : float = 0.2
# 角色在斜面上滑动的加速度
@export var slipAcceleration : float = 1
# y 方向加速度的缩放比例
# 为了让 fallAcceleration 保持 9.8 不变，符合常识
@export var yAccelerationScale : float = 20

# ---组件参数---

# 鼠标灵敏度
@export var mouseSensitivity : float = 0.05
# 鼠标最大移动速度
@export var mouseMoveMaxSpeed : float = 10

# 摄像机最小俯仰角
@export var cameraMinPitch : float = -45
# 摄像机最大俯仰角
@export var cameraMaxPitch : float = 90

# 弹簧臂的最短长度
@export var springarmMinLength : float = 1
# 弹簧臂的最长长度
@export var springarmMaxLength : float = 5
# 弹簧臂的伸缩速度系数
@export var springarmWheelScale : float = 20
# 弹簧臂的最大伸缩速度
@export var springarmMaxWheelSpeed : float = 0.5

# ---组件引用---

# Mesh
@onready var armature = $Armature
# 弹簧臂
@onready var springarm = $SpringArm
# 摄像机
@onready var camera = $SpringArm/Camera
# 动画树
@onready var animTree = $AnimationTree

# ---控制缓存---

# 线速度
var linearVelocity : Vector3 = Vector3.ZERO
# 是否应该旋转弹簧臂
var shouldCameraMove : bool = false
# 物体坐标系二维平面上鼠标运动方向 向上向左为负 向下向右为正
var mouseMoveSpeed : Vector2 = Vector2.ZERO
# 滚轮缩放速度桶
var springarmWheelSpeedBucket : float = 0
# 滚轮缩放速度
var springarmWheelSpeed : float = 0
# 滚轮缩放方向
var springarmWheelDir : float = 0
# y 方向上的加速度
var yAcceleration : float = 0

# 帧函数列表
var funcUpdateList : Array = []

# ---事件---

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event) -> void:
	
	# 如果获得”鼠标运动“事件
	if event is InputEventMouseMotion:
		# 如果得到鼠标相对于最后一帧的位移不是 0 而是 Vector2，说明鼠标相对于最后一帧移动了
		if typeof(event.relative) == TYPE_VECTOR2:
			# 应该旋转摄像机
			shouldCameraMove = true
			# 获得鼠标在一帧内的移动量
			mouseMoveSpeed = event.relative
	# 如果获得“鼠标按下”事件
	elif event is InputEventMouseButton:
		# 如果正在按下
		if event.is_pressed():
			# 如果没有正在计算滚轮速度，那么开始计算
			if funcUpdateList.find(getSpringArmWheelSpeed) == -1:
				funcUpdateList.append(getSpringArmWheelSpeed)
			# 如果是滚轮上滑
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				# 缩小为负
				springarmWheelDir = -1
				# 向桶中添加速度
				springarmWheelSpeedBucket = springarmWheelSpeedBucket + event.get_factor()
			# 如果是滚轮下滑
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				# 放大为正
				springarmWheelDir = 1
				# 向桶中添加速度
				springarmWheelSpeedBucket = springarmWheelSpeedBucket + event.get_factor()

	# 如果按退出键
	if Input.is_action_just_released("ui_cancel"):
		# 在鼠标隐藏和固定之间切换
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# ---自定义函数---

# 玩家运动
func playerMove():
	
	# ---水平方向---
	
	# 控制缓存 移动方向
	var direction = Vector3.ZERO
	
	# 获取摄像机地前后左右方向
	# 注意 xyz 坐标系的方向
	if Input.is_action_pressed("move_right"):
		direction += camera.get_global_transform().basis.x * Vector3(1,0,1)
	if Input.is_action_pressed("move_left"):
		direction -= camera.get_global_transform().basis.x * Vector3(1,0,1)
	if Input.is_action_pressed("move_up"):
		direction -= camera.get_global_transform().basis.z * Vector3(1,0,1)
	if Input.is_action_pressed("move_down"):
		direction += camera.get_global_transform().basis.z * Vector3(1,0,1)
	
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
	
	# ---整理---
	
	# 角色移动
	set_motion_velocity(linearVelocity)
	move_and_slide()
	
	# 设置动画速度
	animTree.set("parameters/BlendSpace1D/blend_position",get_motion_velocity().length()/10)


# 摄像机旋转
func cameraRotate():
	
	# 如果需要旋转摄像机
	if shouldCameraMove:
		# 已经开始旋转摄像机，如果没有新的鼠标事件，之后不需旋转摄像机
		shouldCameraMove = false
		# 旋转摄像机
		camera.rotate_x(-lerp(0, mouseSensitivity, mouseMoveSpeed.y/mouseMoveMaxSpeed))
		# 钳制
		camera.rotation.x = clamp(camera.rotation.x,deg2rad(cameraMinPitch),deg2rad(cameraMaxPitch))
		# 旋转弹簧臂 旋转速度与鼠标移动速度有关 有移速上限
		springarm.rotate_y(-lerp(0, mouseSensitivity, mouseMoveSpeed.x/mouseMoveMaxSpeed))

# 玩家模型旋转
func armatureRotate():
	# armature 前方向
	var armatureForwardVector = armature.get_global_transform().basis.z
	# 弹簧臂 前方向 由于我弹簧臂摆放的设置，这个获得的前方向和期望的前方向是相反的
	var springarmForwardVector = -springarm.get_global_transform().basis.z
	# armature 前方向 和 弹簧臂 前方向 之间的夹角
	var angle = armatureForwardVector.angle_to(springarmForwardVector)
	# 从 armature 前方向 到 弹簧臂 前方向 的向量
	var deltaVector = springarmForwardVector - armatureForwardVector
	
	# rotate_x 增加的方向是逆时针方向
	# 如果从 armature 前方向 到 弹簧臂 前方向 是顺时针方向，就把 angle 设为负
	if deltaVector.dot(armature.get_global_transform().basis.x) < 0:
		angle = -angle
	
	# 应用角色转身速度
	angle *= playerRotSpeed
	
	# armature 旋转
	armature.rotate_y(angle)

# 计算弹簧臂伸缩速度
func getSpringArmWheelSpeed():
	# 自然漏水
	springarmWheelSpeedBucket = springarmWheelSpeedBucket * 0.9
	# 桶中速度限制
	springarmWheelSpeedBucket = clamp(springarmWheelSpeedBucket,0,springarmMaxWheelSpeed*springarmWheelScale)
	print_debug(springarmWheelSpeedBucket)
	# 计算滚轮速度
	springarmWheelSpeed = springarmWheelSpeedBucket/springarmWheelScale
	# 如果桶中没有速度，说明可以停止计算滚轮速度
	if springarmWheelSpeedBucket < 0.5:
		funcUpdateList.erase(getSpringArmWheelSpeed)
		print_debug('Stop func:getSpringArmWheelSpeed')

# 弹簧臂伸缩
func springarmScale():
	
	# 缩放速度不是太小，所以应该缩放弹簧臂
	if springarmWheelSpeedBucket > 0.5:
		# 伸缩弹簧臂
		springarm.set_length(clamp(springarm.get_length()+springarmWheelDir*springarmWheelSpeed,springarmMinLength,springarmMaxLength))

# ---虚函数实现--- 

# 固定帧率执行
func _physics_process(_deltaTime):
	
	# 帧函数调用
	for funcUpdate in funcUpdateList:
		funcUpdate.call()
	
	# 玩家运动
	playerMove()
	# 摄像机旋转
	cameraRotate()
	# 玩家模型旋转
	armatureRotate()
	# 弹簧臂伸缩
	springarmScale()
