"""Tests for scripts/kindle-new-books.py (stdlib only). Run: python3 -m unittest discover -s tests"""

import importlib.util
import pathlib
import struct
import tempfile
import unittest
import zipfile

SCRIPT = pathlib.Path(__file__).resolve().parent.parent / "scripts" / "kindle-new-books.py"
spec = importlib.util.spec_from_file_location("kindle_new_books", SCRIPT)
assert spec is not None and spec.loader is not None
knb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(knb)


def fake_mobi(title="Livro de Teste", author="Fulana de Tal", language="pt", cover=True, text_bytes=4000):
    """A minimal MOBI: PalmDB header + record list, record 0 with PalmDOC + MOBI + EXTH headers."""
    record0 = 78 + 8 * 2 + 2
    exth_records = [(100, author.encode()), (503, title.encode()), (524, language.encode())]
    if cover:
        exth_records.append((201, struct.pack(">I", 0)))
    exth_body = b"".join(struct.pack(">II", t, len(d) + 8) + d for t, d in exth_records)
    exth = b"EXTH" + struct.pack(">II", 12 + len(exth_body), len(exth_records)) + exth_body
    mobi_len = 0xE8
    mobi = bytearray(mobi_len)
    mobi[0:4] = b"MOBI"
    struct.pack_into(">I", mobi, 0x04, mobi_len)
    struct.pack_into(">I", mobi, 0x0C, 65001)            # UTF-8
    struct.pack_into(">I", mobi, 0x5C, 1)                # first image record
    struct.pack_into(">I", mobi, 0x70, 0x40)             # EXTH present
    name = b"Nome Interno"
    name_offset = 16 + mobi_len + len(exth)
    struct.pack_into(">I", mobi, 0x44, name_offset)
    struct.pack_into(">I", mobi, 0x48, len(name))
    palmdoc = struct.pack(">HHIHHHH", 2, 0, text_bytes, 1, 4096, 0, 0)
    rec0 = palmdoc + bytes(mobi) + exth + name + b"\0\0"
    header = bytearray(78)
    header[0:4] = b"Test"
    header[60:68] = b"BOOKMOBI"
    struct.pack_into(">H", header, 76, 2)                # number of records
    records = struct.pack(">II", record0, 0) + struct.pack(">II", record0 + len(rec0), 1)
    return bytes(header) + records + b"\0\0" + rec0 + b"\xff" * 16


def fake_epub(path, toc_entries=3, spine=5, language="pt-BR"):
    opf_items = ['<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>',
                 '<item id="cover" href="cover.jpg" media-type="image/jpeg" properties="cover-image"/>']
    opf_items += [f'<item id="c{i}" href="c{i}.xhtml" media-type="application/xhtml+xml"/>' for i in range(spine)]
    itemrefs = "".join(f'<itemref idref="c{i}"/>' for i in range(spine))
    nav_points = "".join(
        f'<navPoint id="n{i}"><navLabel><text>Cap {i}</text></navLabel><content src="c{i}.xhtml"/></navPoint>'
        for i in range(toc_entries))
    with zipfile.ZipFile(path, "w") as z:
        z.writestr("mimetype", "application/epub+zip")
        z.writestr("META-INF/container.xml",
                   '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles>'
                   '<rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>'
                   '</rootfiles></container>')
        z.writestr("OEBPS/content.opf",
                   '<package xmlns="http://www.idpf.org/2007/opf" xmlns:dc="http://purl.org/dc/elements/1.1/">'
                   f'<metadata><dc:title>Título Bom</dc:title><dc:creator>Autora Boa</dc:creator>'
                   f'<dc:language>{language}</dc:language></metadata>'
                   f'<manifest>{"".join(opf_items)}</manifest><spine toc="ncx">{itemrefs}</spine></package>')
        z.writestr("OEBPS/toc.ncx",
                   f'<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/"><navMap>{nav_points}</navMap></ncx>')
        z.writestr("OEBPS/cover.jpg", b"\xff\xd8\xff")
        for i in range(spine):
            z.writestr(f"OEBPS/c{i}.xhtml", f"<html><body><p>Texto do capítulo {i} com palavras.</p></body></html>")


class NewBooks(unittest.TestCase):
    def test_new_or_changed_lists_unknown_and_modified_books(self):
        inventory = [{"path": "/d/a.epub", "bytes": 10, "mtime": 1},
                     {"path": "/d/b.pdf", "bytes": 20, "mtime": 2},
                     {"path": "/d/c.pdf", "bytes": 30, "mtime": 3}]
        state = {"/d/a.epub": {"bytes": 10, "mtime": 1}, "/d/b.pdf": {"bytes": 21, "mtime": 2}}
        self.assertEqual([b["path"] for b in knb.new_or_changed(inventory, state)], ["/d/b.pdf", "/d/c.pdf"])

    def test_parse_cache_reads_unit_separated_rows(self):
        text = "/d/a.pdf\x1fY\x1fpt\x1f107\x1f\x1fTítulo\x1fAutor\n/d/b.epub\x1f\x1f\x1f\x1f1\x1f\x1f\n"
        rows = knb.parse_cache(text)
        self.assertEqual(rows["/d/a.pdf"]["has_cover"], "Y")
        self.assertEqual(rows["/d/a.pdf"]["pages"], "107")
        self.assertEqual(rows["/d/b.epub"]["unsupported"], "1")


class Analysis(unittest.TestCase):
    def test_mobi_info_reads_exth_metadata(self):
        info = knb.mobi_info(fake_mobi())
        self.assertEqual(info["title"], "Livro de Teste")
        self.assertEqual(info["author"], "Fulana de Tal")
        self.assertEqual(info["language"], "pt")
        self.assertTrue(info["has_cover"])
        self.assertEqual(info["encryption"], 0)

    def test_mobi_info_falls_back_to_the_internal_name(self):
        data = fake_mobi(title="", author="")
        self.assertEqual(knb.mobi_info(data)["title"], "Nome Interno")

    def test_mobi_info_rejects_other_files(self):
        self.assertIsNone(knb.mobi_info(b"%PDF-1.7" + b"\0" * 200))

    def test_epub_info_reads_opf_and_toc(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "x.epub"
            fake_epub(path, toc_entries=3, spine=5)
            info = knb.epub_info(path)
        self.assertEqual(info["title"], "Título Bom")
        self.assertEqual(info["author"], "Autora Boa")
        self.assertEqual(info["language"], "pt-BR")
        self.assertEqual(info["toc_entries"], 3)
        self.assertEqual(info["spine"], 5)
        self.assertTrue(info["has_cover"])
        self.assertGreater(info["letters"], 50)

    def test_is_scanned_matches_the_kindle_rule(self):
        self.assertTrue(knb.is_scanned([0, 0, 3, 0, 0, 0]))
        self.assertFalse(knb.is_scanned([1800, 2100, 0, 1500, 2300, 1900]))
        self.assertIsNone(knb.is_scanned([]))
        self.assertEqual(knb.sample_pages(100, 6), [9, 26, 42, 59, 76, 92])


class Issues(unittest.TestCase):
    def book(self, **kw):
        b = {"path": "/d/livro-sem-nome.epub", "ext": "epub", "custom": {}, "original": {}, "custom_cover": False}
        b.update(kw)
        return b

    def test_missing_author_cover_and_type_are_reported(self):
        cache = {"title": "Um Livro", "authors": "", "has_cover": "", "keywords": ""}
        keys = knb.issue_keys(self.book(), cache, {"toc_entries": 5, "spine": 5})
        self.assertIn("no_author", keys)
        self.assertIn("no_cover", keys)
        self.assertIn("no_type_tag", keys)
        self.assertNotIn("no_title", keys)

    def test_title_equal_to_the_file_name_counts_as_missing(self):
        cache = {"title": "livro-sem-nome", "authors": "A", "has_cover": "Y", "keywords": "Tipo: Livro"}
        self.assertIn("no_title", knb.issue_keys(self.book(), cache, {}))

    def test_a_real_title_that_matches_the_file_name_is_fine(self):
        cache = {"title": "Maus", "authors": "A", "has_cover": "Y", "keywords": "Tipo: Livro"}
        self.assertNotIn("no_title", knb.issue_keys(self.book(path="/d/Maus.mobi", ext="mobi"), cache, {}))

    def test_image_mobi_without_comic_tag_is_a_comic_hint(self):
        cache = {"title": "T", "authors": "A", "has_cover": "Y", "keywords": "Tipo: Livro"}
        mobi = self.book(path="/d/x.mobi", ext="mobi")
        comic = {"encryption": 0, "image_records": 271, "text_bytes": 41479}
        novel = {"encryption": 0, "image_records": 25, "text_bytes": 600000}
        self.assertIn("maybe_comic", knb.issue_keys(mobi, cache, comic))
        self.assertNotIn("maybe_comic", knb.issue_keys(mobi, cache, novel))

    def test_weak_toc_and_comic_hints(self):
        cache = {"title": "T", "authors": "A", "has_cover": "Y", "keywords": "Tipo: Livro"}
        self.assertIn("weak_toc", knb.issue_keys(self.book(), cache, {"toc_entries": 1, "spine": 8}))
        pdf = self.book(path="/d/x.pdf", ext="pdf")
        keys = knb.issue_keys(pdf, dict(cache, keywords="Tipo: PDF"), {"scanned": True})
        self.assertIn("scanned", keys)
        self.assertIn("maybe_comic", keys)
        tagged = knb.issue_keys(pdf, dict(cache, keywords="Tipo: PDF\nTipo: Quadrinho"), {"scanned": True})
        self.assertNotIn("maybe_comic", tagged)

    def test_store_books_only_get_library_checks(self):
        store = self.book(path="/d/x.kfx", ext="kfx")
        cache = {"title": "T", "authors": "A", "has_cover": "Y", "keywords": "Tipo: Amazon"}
        self.assertEqual(knb.issue_keys(store, cache, None), ["native_reader"])

    def test_books_not_indexed_yet(self):
        self.assertIn("not_indexed", knb.issue_keys(self.book(), None, {}))

    def test_problem_count_ignores_information(self):
        self.assertEqual(knb.problem_count(["native_reader", "scanned", "no_cover"]), 1)


if __name__ == "__main__":
    unittest.main()
