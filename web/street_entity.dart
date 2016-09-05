part of CoUMapFiller;

@Mappable()
class StreetEntity {
	StreetEntity();

	StreetEntity.create({
						this.id,
						this.type,
						this.tsid,
						this.x: 0,
						this.y: 0,
						this.z: 0,
						this.h_flip: false,
						this.rotation: 0,
						this.metadata_json
						}) {
		assert(id != null);
		assert(type != null);
		assert(tsid != null);
	}

	/// Unique ID across all streets
	String id;

	String type;

	/// Must start with L
	String tsid;

	int x, y, z, rotation;

	bool h_flip;

	String metadata_json = '{}';

	@override String toString() => "<StreetEntity $id ($type) on $tsid at ($x, $y, $z), flip: $h_flip, rotation: $rotation with metadata $metadata_json>";
}

@Mappable()
class EntitySet {
	String tsid;
	List<StreetEntity> entities;
}