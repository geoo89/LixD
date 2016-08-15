module file.filename.argfile;

/* Filenames that got passed to this application as command-line arguments.
 * These should be relative to the working directory, not to the virtual
 * file system (VFS) in vfsfile.d.
 */

import std.algorithm;
import std.file;
import std.range;
import std.stdio; // File
import std.string;

import file.filename.base;

public alias ArgumentFilename = immutable(_ArgumentFilename);

private class _ArgumentFilename : IFilename {
private:
    immutable string _s;

public:
    this(string raw) immutable nothrow
    {
        try
            _s = raw.tr("\\", "/");
        catch (Exception)
            { }
    }

    @property string rootless() nothrow immutable { return _s; }

    // Return extension without dot.
    @property string extension() nothrow immutable
    {
        try {
            auto extLen = _s.walkLength
                        - _s.retro.findAmong(['.', '/']).walkLength;
            return extLen < _s.length && _s[$-1 - extLen] == '/'
                ? ""
                : _s[($ - extLen) .. $];
        }
        catch (Exception)
            return "";
    }

    @property string file() nothrow immutable
    {
        try
            return _s[_s.retro.find('/').walkLength .. $];
        catch (Exception)
            return _s;
    }

    @property string rootlessNoExt() nothrow immutable
    {
        return _s[0 .. $ - extension.length];
    }

    @property string dirRootless() nothrow immutable
    {
        return _s[0 .. $ - file.length];
    }

    unittest {
        auto fn = new immutable(typeof(this))("./dir1/dir2/dir3/myfile.txt");
        assert (fn.file == "myfile.txt");
        assert (fn.dirRootless == "./dir1/dir2/dir3/", fn.dirRootless);
    }

    // Implement these if needed. I don't think we need them
    @property string fileNoExtNoPre() nothrow immutable { assert (false); }
    @property string dirInnermost() nothrow immutable { assert (false); }
    @property char preExtension() nothrow immutable { assert (false); }

    override bool opEquals(Object rhs_obj) const
    {
        auto rhs = cast (const typeof(this)) rhs_obj;
        return rhs && this._s == rhs._s;
    }

    @trusted override size_t toHash() const nothrow
    {
        return typeid(_s).getHash(&_s);
    }

    ArgumentFilename guaranteedDirOnly() nothrow immutable
    {
        return file.empty ? this : new ArgumentFilename(dirRootless);
    }

    // These can throw on file 404
    std.stdio.File openForReading(in string mode = "r") immutable
    {
        return std.stdio.File(_s, mode);
    }

    std.stdio.File openForWriting(in string mode = "w") immutable
    {
        this.mkdirRecurse();
        return std.stdio.File(_s, mode);
    }

    // Silently return null if file not found
    const(char*) stringzForReading() nothrow immutable { return _s.toStringz; }
    const(char*) stringzForWriting() nothrow immutable { return _s.toStringz; }

    // dirExists(a/b/) checks if b exists.
    // dirExists(a/b/c) checks if b exists, no matter whether file c is inside.
    bool fileExists() nothrow immutable
    {
        try
            return std.file.exists(_s) && ! std.file.isDir(_s);
        catch (Exception)
            return false;
    }

    bool dirExists() nothrow immutable
    {
        try
            return std.file.exists(_s) && std.file.isDir(_s);
        catch (Exception)
            return false;
    }

    // These throw on error.
    void mkdirRecurse() immutable { std.file.mkdirRecurse(_s); }
    void deleteFile() immutable { if (fileExists) std.file.remove(_s); }

protected:
    MutFilename[] findImpl(in SpanMode spanMode,
                           in bool wantDirs, in string what) immutable
    {
        if (! std.file.exists(_s) || ! std.file.isDir(_s))
            return [];
        return std.file.dirEntries(_s, spanMode, true)
            .filter!(f => std.file.isDir(f.name) == wantDirs
                       && f.hasEnding(what))
            .map!(f => f.tr("\\", "/") ~ (wantDirs ? "/" : ""))
            .map!(f => MutFilename(new ArgumentFilename(f)))
            .array;
    }
}
// end class

