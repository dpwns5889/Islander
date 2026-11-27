extends RefCounted
## 옛 점검용 작은 맵: 0.64까지의 15x15 필드와 바깥 8칸 바다(-8~22)와 같은 범위만 쓴다.
## 96x96 전체에서는 해적선이 먼 가장자리에서 와서 옛 점검의 시간 안에 끝나지 않는다


static func make() -> Field:
	var f: Field = Field.new()
	f.bounds = Rect2i(-8, -8, 31, 31)
	return f
