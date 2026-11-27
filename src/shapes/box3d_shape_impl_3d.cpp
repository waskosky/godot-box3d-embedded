#include "box3d_shape_impl_3d.hpp"

#include "../objects/box3d_shaped_object_impl_3d.hpp"

#include <box3d/collision.h>

Box3DShapeImpl3D::~Box3DShapeImpl3D() {
	_clear_contact_query_hull();
}

const b3HullData* Box3DShapeImpl3D::get_contact_query_hull(const b3ShapeProxy& p_local_proxy) const {
	b3HullData* cached = contact_query_hull.load(std::memory_order_acquire);
	if (cached != nullptr) {
		return cached;
	}
	b3HullData* created = b3CreateHull(p_local_proxy.points, p_local_proxy.count, MIN(p_local_proxy.count, 255));
	if (created == nullptr) {
		return nullptr;
	}
	// Read-only queries can share this immutable hull. As with the underlying
	// shape data, editing or freeing a resource must not race with a query.
	if (contact_query_hull.compare_exchange_strong(cached, created, std::memory_order_acq_rel)) {
		return created;
	}
	b3DestroyHull(created);
	return cached;
}

void Box3DShapeImpl3D::_clear_contact_query_hull() {
	if (b3HullData* hull = contact_query_hull.exchange(nullptr)) {
		b3DestroyHull(hull);
	}
}

void Box3DShapeImpl3D::add_owner(Box3DShapedObjectImpl3D* p_owner) {
	int32_t* count = owner_ref_counts.getptr(p_owner);
	if (count == nullptr) {
		owner_ref_counts.insert(p_owner, 1);
	} else {
		(*count)++;
	}
}

void Box3DShapeImpl3D::remove_owner(Box3DShapedObjectImpl3D* p_owner) {
	int32_t* count = owner_ref_counts.getptr(p_owner);
	ERR_FAIL_NULL(count);
	(*count)--;
	if (*count == 0) {
		owner_ref_counts.erase(p_owner);
	}
}

void Box3DShapeImpl3D::notify_owners_shape_data_will_change() {
	_clear_contact_query_hull();
	for (const KeyValue<Box3DShapedObjectImpl3D*, int32_t>& entry : owner_ref_counts) {
		entry.key->shape_data_will_change(this);
	}
}

void Box3DShapeImpl3D::notify_owners_shape_data_changed() {
	for (const KeyValue<Box3DShapedObjectImpl3D*, int32_t>& entry : owner_ref_counts) {
		entry.key->shape_data_changed(this);
	}
}

void Box3DShapeImpl3D::remove_self() {
	// Removing every attachment changes this map through remove_owner(), so iterate over a
	// copy. A single owner may attach the same shared Shape3D more than once.
	const HashMap<Box3DShapedObjectImpl3D*, int32_t> owners_copy(owner_ref_counts);
	for (const KeyValue<Box3DShapedObjectImpl3D*, int32_t>& entry : owners_copy) {
		entry.key->remove_shape(this);
	}
}
