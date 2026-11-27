#pragma once

#include "box3d_shape_proxy.hpp"

#include <box3d/box3d.h>
#include <godot_cpp/templates/local_vector.hpp>

// Read-only contact geometry in world space. The normal points from the target
// toward the query shape; separation is negative for penetration.
struct Box3DRecoveryContact {
	b3Vec3 point;
	b3Vec3 normal;
	float separation;
};

// A resource query has no live fixture. Prepare local geometry at the first
// eligible target and reuse the shape resource's hull across queries.
class Box3DContactQuery3D {
public:
	explicit Box3DContactQuery3D(const Box3DShapeImpl3D* p_shape);
	Box3DContactQuery3D(const Box3DContactQuery3D&) = delete;
	Box3DContactQuery3D& operator=(const Box3DContactQuery3D&) = delete;

	void contacts(b3Transform p_transform, b3ShapeId p_target, float p_margin,
			godot::LocalVector<Box3DRecoveryContact>& r_contacts) const;

private:
	Box3DShapeProxy3D local_proxy;
	const b3HullData* hull = nullptr;
};

// Live fixtures already contain local shape transforms (including baked meshes).
// Supply the hypothetical query body transform without changing the live body.
void box3d_recovery_contacts(b3ShapeId p_query, b3Transform p_query_transform,
		b3ShapeId p_target, float p_margin, godot::LocalVector<Box3DRecoveryContact>& r_contacts);

// Fraction where the gap reaches p_margin on a motion that touches the target, or -1 if it never touches.
float box3d_cast_to_contact(b3ShapeId p_query, b3Transform p_query_transform, b3Vec3 p_motion,
		b3ShapeId p_target, float p_margin, Box3DRecoveryContact& r_contact);
