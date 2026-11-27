#pragma once

#include <godot_cpp/classes/physics_server3d.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/variant/aabb.hpp>
#include <godot_cpp/variant/rid.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <atomic>

using namespace godot;

class Box3DShapedObjectImpl3D;
struct b3HullData;
struct b3ShapeProxy;

// One instance per Shape3D RID. Holds the Godot-facing shape data, shared query
// geometry, and the bodies/areas whose native fixtures must be refreshed on edits.
class Box3DShapeImpl3D {
public:
	using ShapeType = PhysicsServer3D::ShapeType;

	virtual ~Box3DShapeImpl3D();

	RID get_rid() const { return rid; }

	void set_rid(const RID& p_rid) { rid = p_rid; }

	virtual ShapeType get_type() const = 0;

	virtual Variant get_data() const = 0;

	virtual void set_data(const Variant& p_data) = 0;

	virtual AABB get_aabb() const = 0;

	// p_local_proxy contains uninflated, shape-local points. The hull lives until
	// the next shape data change or the resource's destruction.
	const b3HullData* get_contact_query_hull(const b3ShapeProxy& p_local_proxy) const;

	void add_owner(Box3DShapedObjectImpl3D* p_owner);

	void remove_owner(Box3DShapedObjectImpl3D* p_owner);

	void notify_owners_shape_data_will_change();

	void notify_owners_shape_data_changed();

	void remove_self();

protected:
	RID rid;
	HashMap<Box3DShapedObjectImpl3D*, int32_t> owner_ref_counts;

private:
	void _clear_contact_query_hull();

	mutable std::atomic<b3HullData*> contact_query_hull{nullptr};
};
