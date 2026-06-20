components {
  id: "marble"
  component: "/assets/go/marble/marble.script"
}
embedded_components {
  id: "sprite"
  type: "sprite"
  data: "default_animation: \"marble\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/assets/go/marble/marble.atlas\"\n"
  "}\n"
  ""
  scale {
    x: 0.6
    y: 0.6
  }
}
embedded_components {
  id: "collisionobject"
  type: "collisionobject"
  data: "type: COLLISION_OBJECT_TYPE_DYNAMIC\n"
  "mass: 0.5\n"
  "friction: 0.1\n"
  "restitution: 0.05\n"
  "group: \"marble\"\n"
  "mask: \"default\"\n"
  "mask: \"complete\"\n"
  "mask: \"marble\"\n"
  "embedded_collision_shape {\n"
  "  shapes {\n"
  "    shape_type: TYPE_SPHERE\n"
  "    position {\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 0\n"
  "    count: 1\n"
  "  }\n"
  "  data: 20.0\n"
  "}\n"
  "angular_damping: 0.02\n"
  ""
}
