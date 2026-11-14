#include "box3d_concave_polygon_shape_impl_3d.hpp"

#include "../misc/type_conversions.hpp"

#include <box3d/collision.h>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/templates/local_vector.hpp>
#include <godot_cpp/variant/vector3i.hpp>

Box3DConcavePolygonShapeImpl3D::~Box3DConcavePolygonShapeImpl3D() {
	if (mesh != nullptr) {
		b3DestroyMesh(mesh);
		mesh = nullptr;
	}
}

Variant Box3DConcavePolygonShapeImpl3D::get_data() const {
	Dictionary data;
	data["faces"] = faces;
	data["backface_collision"] = backface_collision;
	return data;
}

void Box3DConcavePolygonShapeImpl3D::set_data(const Variant& p_data) {
	if (p_data.get_type() == Variant::DICTIONARY) {
		const Dictionary data = p_data;
		ERR_FAIL_COND(!data.has("faces"));
		faces = data["faces"];
		backface_collision = data.get("backface_collision", false);
	} else {
		ERR_FAIL_COND(p_data.get_type() != Variant::PACKED_VECTOR3_ARRAY);
		faces = p_data;
		backface_collision = false;
	}
	_rebuild_mesh();
}

b3MeshData* Box3DConcavePolygonShapeImpl3D::build_mesh(
		const PackedVector3Array& p_faces,
		const Transform3D& p_transform,
		LocalVector<int32_t>* p_input_faces) {
	if (p_input_faces != nullptr) {
		p_input_faces->clear();
	}
	const int face_count = p_faces.size();
	if (face_count < 3 || face_count % 3 != 0) {
		return nullptr;
	}

	const int triangle_count = face_count / 3;

	LocalVector<b3Vec3> vertices;
	LocalVector<int32_t> indices;
	indices.resize(face_count);
	HashMap<Vector3, int32_t> shared_vertices;

	// Adjacency requires shared vertex IDs. Merge exact duplicates only: nearby
	// surfaces must not be welded together by an arbitrary tolerance.
	for (int i = 0; i < face_count; i++) {
		const Vector3 vertex = p_faces[i];
		const int32_t* existing = shared_vertices.getptr(vertex);
		if (existing != nullptr) {
			indices[i] = *existing;
		} else {
			const int32_t index = (int32_t)vertices.size();
			shared_vertices.insert(vertex, index);
			vertices.push_back(godot_to_b3(p_transform.xform(vertex)));
			indices[i] = index;
		}
	}

	// Box3D meshes use the opposite winding order to Godot's concave shapes, so emit
	// each triangle reversed (v0, v2, v1) to make trimesh collision register.
	HashMap<Vector3i, int32_t> source_triangles;
	for (int t = 0; t < triangle_count; t++) {
		const int32_t second = indices[t * 3 + 1];
		indices[t * 3 + 1] = indices[t * 3 + 2];
		indices[t * 3 + 2] = second;
		if (p_input_faces != nullptr) {
			const Vector3i triangle(indices[t * 3], indices[t * 3 + 1], indices[t * 3 + 2]);
			// Coincident duplicate triangles are indistinguishable; keep the first input face.
			if (!source_triangles.has(triangle)) {
				source_triangles.insert(triangle, t);
			}
		}
	}

	b3MeshDef def = {};
	def.vertices = vertices.ptr();
	def.indices = indices.ptr();
	def.materialIndices = nullptr;
	def.weldTolerance = 0.0f;
	def.vertexCount = (int32_t)vertices.size();
	def.triangleCount = triangle_count;
	def.weldVertices = false;
	def.useMedianSplit = false;
	def.identifyEdges = true;

	b3MeshData* result = b3CreateMesh(&def, nullptr, 0);
	if (result != nullptr && p_input_faces != nullptr) {
		// The BVH reorders (and may discard degenerate) triangles. Preserve Godot's
		// input face indices explicitly instead of encoding them in unwelded vertex IDs.
		p_input_faces->resize(result->triangleCount);
		const b3MeshTriangle* triangles = b3GetMeshTriangles(result);
		for (int32_t t = 0; t < result->triangleCount; t++) {
			const b3MeshTriangle& triangle = triangles[t];
			const int32_t* face = source_triangles.getptr(Vector3i(triangle.index1, triangle.index2, triangle.index3));
			(*p_input_faces)[t] = face != nullptr ? *face : -1;
		}
	}
	return result;
}

void Box3DConcavePolygonShapeImpl3D::_rebuild_mesh() {
	if (mesh != nullptr) {
		b3DestroyMesh(mesh);
		mesh = nullptr;
	}
	input_faces.clear();

	const int face_count = faces.size();
	if (face_count < 3 || face_count % 3 != 0) {
		return;
	}

	Vector3 min_point = faces[0];
	Vector3 max_point = faces[0];
	for (int i = 0; i < face_count; i++) {
		min_point = min_point.min(faces[i]);
		max_point = max_point.max(faces[i]);
	}

	aabb = AABB(min_point, max_point - min_point);
	mesh = build_mesh(faces, Transform3D(), &input_faces);
}
