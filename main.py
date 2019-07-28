import dataclasses

@dataclasses.dataclass
class Point:
    x: float
    y: float
    z: float = 0.0

p = Point(1.5, 2.5)

print(f'Set your Point is {p}')
