#!/usr/bin/env python3
"""What every FBX in a directory tree asks for, read straight out of the binaries.

    ./tools/fbx_texture_map.py assets/mistage_village assets/mistage_market

Prints, per directory tree: the texture basenames the models name, the material
each one hangs off, and whether a file of that basename is now findable at or
above the model -- which is exactly the condition Godot's importer falls back to
once the absolute Windows path inside the file resolves nowhere.

This exists so the mapping in tools/extract_mistage.sh is evidence rather than a
claim. It reads the FBX itself and never loads the engine, so it answers "what
did the artist name" independently of "what did Godot manage to bind", which is
what tools/inventory_pack.sh answers.

Exits non-zero when a basename is not findable, which the Fantasy Village pack
always is: two of its materials name an atlas belonging to a different Mistage
pack. That is a report, not a build gate -- reports/mistage-packs.md is where the
two are named and excused, and tools/inventory_pack.sh --every-material is the
check that has excuses and can be wired to a build.
"""
import collections
import struct
import sys
from pathlib import Path

_SCALARS = {'C': '?', 'B': '?', 'Y': 'h', 'I': 'i', 'L': 'q', 'F': 'f', 'D': 'd'}


class _Node:
	def __init__(self, name):
		self.name = name
		self.props = []
		self.children = []


def _read_props(data, off, count):
	out = []
	for _ in range(count):
		code = chr(data[off])
		off += 1
		fmt = _SCALARS.get(code)
		if fmt is not None:
			out.append(struct.unpack_from('<' + fmt, data, off)[0])
			off += struct.calcsize(fmt)
		elif code in 'SR':
			length = struct.unpack_from('<I', data, off)[0]
			off += 4
			out.append(data[off:off + length])
			off += length
		elif code in 'fdlbic':  # arrays; their contents are geometry, not wanted
			_, _, byte_len = struct.unpack_from('<III', data, off)
			off += 12 + byte_len
			out.append(None)
		else:
			raise ValueError('unknown FBX property typecode %r' % code)
	return out, off


def _read_node(data, off, version):
	if version >= 7500:
		end, nprops, _ = struct.unpack_from('<QQQ', data, off)
		off += 24
	else:
		end, nprops, _ = struct.unpack_from('<III', data, off)
		off += 12
	name_len = data[off]
	off += 1
	if end == 0:
		return None, off
	node = _Node(data[off:off + name_len].decode('latin1'))
	off += name_len
	node.props, off = _read_props(data, off, nprops)
	while off < end:
		child, off = _read_node(data, off, version)
		if child is None:
			break
		node.children.append(child)
	return node, end


def parse(path):
	data = Path(path).read_bytes()
	version = struct.unpack_from('<I', data, 23)[0]
	off, root = 27, _Node('root')
	while off < len(data) - 160:
		node, off = _read_node(data, off, version)
		if node is None:
			break
		root.children.append(node)
	return root


def objects_and_connections(path):
	"""{id: (class, name, filename)} and [(src_id, dst_id, property)]."""
	root = parse(path)
	objects, connections = {}, []
	for top in root.children:
		if top.name == 'Objects':
			for obj in top.children:
				name = ''
				if len(obj.props) > 1 and isinstance(obj.props[1], bytes):
					name = obj.props[1].split(b'\x00\x01')[0].decode('latin1')
				filename = ''
				if obj.name in ('Texture', 'Video'):
					for child in obj.children:
						if child.name in ('RelativeFilename', 'FileName') and child.props:
							if isinstance(child.props[0], bytes):
								filename = child.props[0].decode('latin1')
				objects[obj.props[0]] = (obj.name, name, filename)
		elif top.name == 'Connections':
			for conn in top.children:
				if len(conn.props) >= 3:
					connections.append((conn.props[1], conn.props[2],
						conn.props[3] if len(conn.props) > 3 else None))
	return objects, connections


def findable(model: Path, basename: str, root: Path) -> bool:
	"""Whether Godot's basename fallback would find the texture: beside the model
	or in any directory above it, up to the pack root."""
	here = model.parent
	while True:
		if (here / basename).exists():
			return True
		if here == root or here.parent == here:
			return False
		here = here.parent


def survey(root: Path):
	asks = collections.Counter()       # (material, video name, basename)
	untextured = collections.Counter()  # material with no texture at all
	missing = collections.Counter()     # basename that is not findable
	models = 0
	for model in sorted(root.rglob('*.fbx')):
		models += 1
		objects, connections = objects_and_connections(str(model))
		texture_video = {}
		for src, dst, _ in connections:
			a, b = objects.get(src), objects.get(dst)
			if a and b and a[0] == 'Video' and b[0] == 'Texture':
				texture_video[dst] = (a[1], a[2].replace('\\', '/').split('/')[-1])
		textured = set()
		for src, dst, prop in connections:
			a, b = objects.get(src), objects.get(dst)
			if a and b and a[0] == 'Texture' and b[0] == 'Material':
				video, basename = texture_video.get(src, ('?', '?'))
				if prop == b'DiffuseColor':
					asks[(b[1], video, basename)] += 1
					if not findable(model, basename, root):
						missing[(b[1], basename)] += 1
				textured.add(dst)
		for oid, (cls, name, _) in objects.items():
			if cls == 'Material' and oid not in textured:
				untextured[name] += 1
	return models, asks, untextured, missing


def main(argv):
	roots = [Path(a) for a in argv[1:]] or [Path('assets/mistage_village'),
		Path('assets/mistage_market')]
	failed = 0
	for root in roots:
		models, asks, untextured, missing = survey(root)
		print('=== %s: %d models' % (root, models))
		print('  material                    atlas the artist named      basename asked for   models')
		for (material, video, basename), n in asks.most_common():
			mark = '  MISSING' if missing.get((material, basename)) else ''
			print('  %-26s  %-26s  %-20s %6d%s' % (material, video, basename, n, mark))
		if untextured:
			print('  materials that name no texture at all (emissive/glow; not a failure):')
			for material, n in untextured.most_common():
				print('  %-26s  %-26s  %-20s %6d' % (material, '-', '-', n))
		if missing:
			failed += 1
			print('  NOT FINDABLE at or above the model:')
			for (material, basename), n in missing.most_common():
				print('    %s wants %s, on %d models' % (material, basename, n))
	return 1 if failed else 0


if __name__ == '__main__':
	sys.exit(main(sys.argv))
