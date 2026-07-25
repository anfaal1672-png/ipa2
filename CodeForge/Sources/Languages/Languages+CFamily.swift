import Foundation

extension Languages {

    static let preprocessorRule = RegexRule("^[ \\t]*#[ \\t]*[a-z_]+", .preprocessor,
                                            options: [.anchorsMatchLines])

    static var cFamily: [LanguageDefinition] {
        var result: [LanguageDefinition] = []

        // ---- C -----------------------------------------------------------
        var c = LanguageDefinition.cLike(
            id: "c", name: "C",
            extensions: ["c", "h"],
            keywords: "auto const extern inline register restrict signed sizeof static struct typedef union unsigned volatile _Alignas _Alignof _Atomic _Bool _Complex _Generic _Noreturn _Static_assert _Thread_local enum",
            controlKeywords: "if else for while do switch case default break continue return goto",
            types: "void char short int long float double bool size_t ssize_t ptrdiff_t int8_t int16_t int32_t int64_t uint8_t uint16_t uint32_t uint64_t intptr_t uintptr_t FILE va_list wchar_t",
            constants: "NULL true false EOF stdin stdout stderr __FILE__ __LINE__ __func__",
            builtins: "printf sprintf snprintf fprintf scanf sscanf malloc calloc realloc free memcpy memmove memset strlen strcpy strncpy strcmp strncmp strcat strdup fopen fclose fread fwrite fseek ftell exit abort assert qsort bsearch",
            rules: [preprocessorRule,
                    RegexRule("#\\s*include\\s+(<[^>]*>)", .string, group: 1)])
        c.docLineComments = ["///"]
        c.blockComments = [BlockComment("/**", "*/", doc: true), BlockComment("/*", "*/")]
        c.strings = [StringRule(open: "\""), StringRule(open: "'")]
        c.keyboardExtras = ["{", "}", "(", ")", ";", "*", "&", "->", "#"]
        result.append(c)

        // ---- C++ ---------------------------------------------------------
        var cpp = c
        cpp.id = "cpp"
        cpp.name = "C++"
        cpp.extensions = ["cpp", "cc", "cxx", "c++", "hpp", "hh", "hxx", "h++", "ipp", "tpp", "inl"]
        cpp.keywords.formUnion([
            "class", "namespace", "template", "typename", "using", "public", "private", "protected",
            "virtual", "override", "final", "friend", "operator", "new", "delete", "this", "explicit",
            "mutable", "constexpr", "consteval", "constinit", "decltype", "noexcept", "nullptr_t",
            "static_cast", "dynamic_cast", "const_cast", "reinterpret_cast", "typeid", "concept",
            "requires", "co_await", "co_return", "co_yield", "export", "module", "import", "alignas",
            "alignof", "thread_local", "static_assert"
        ])
        cpp.controlKeywords.formUnion(["try", "catch", "throw"])
        cpp.types.formUnion([
            "string", "wstring", "vector", "map", "unordered_map", "set", "unordered_set", "list",
            "deque", "array", "pair", "tuple", "optional", "variant", "any", "shared_ptr",
            "unique_ptr", "weak_ptr", "function", "thread", "mutex", "atomic", "ostream", "istream",
            "stringstream", "int8_t", "uint8_t", "span", "string_view"
        ])
        cpp.constants.formUnion(["nullptr", "true", "false"])
        cpp.builtins.formUnion(["std", "cout", "cin", "cerr", "endl", "make_shared", "make_unique", "move", "forward", "swap", "begin", "end", "size"])
        result.append(cpp)

        // ---- Objective-C --------------------------------------------------
        var objc = LanguageDefinition.cLike(
            id: "objectivec", name: "Objective-C",
            extensions: ["m", "mm"],
            keywords: "self super id nil Nil SEL IMP Class Protocol BOOL instancetype const static extern inline typedef struct enum union volatile sizeof strong weak assign copy retain nonatomic atomic readonly readwrite nullable nonnull",
            controlKeywords: "if else for while do switch case default break continue return goto @try @catch @finally @throw in",
            types: "NSString NSMutableString NSArray NSMutableArray NSDictionary NSMutableDictionary NSSet NSNumber NSData NSDate NSError NSURL NSObject UIView UIViewController UIColor UIImage CGRect CGPoint CGSize NSInteger NSUInteger CGFloat void char int long float double",
            constants: "YES NO nil NULL",
            rules: [preprocessorRule,
                    RegexRule("@[a-zA-Z_][a-zA-Z0-9_]*", .keyword),
                    RegexRule("\\b([a-zA-Z_][a-zA-Z0-9_]*)\\s*:", .property, group: 1)])
        objc.strings = [StringRule(open: "@\""), StringRule(open: "\""), StringRule(open: "'")]
        objc.identifierExtras = ["_", "@"]
        objc.identifierStartExtras = ["_", "@"]
        objc.keyboardExtras = ["[", "]", "@", "{", "}", "*", ";", ":"]
        result.append(objc)

        var objcpp = objc
        objcpp.id = "objectivecpp"
        objcpp.name = "Objective-C++"
        objcpp.extensions = ["mm"]
        objcpp.keywords.formUnion(cpp.keywords)
        result.append(objcpp)

        // ---- C# ------------------------------------------------------------
        var cs = LanguageDefinition.cLike(
            id: "csharp", name: "C#",
            extensions: ["cs", "csx"],
            keywords: "abstract as async await base checked class const delegate event explicit extern fixed get set implicit in interface internal is lock namespace new operator out override params partial private protected public readonly record ref sealed sizeof stackalloc static struct this typeof unchecked unsafe using virtual volatile where yield enum init required with global var value",
            controlKeywords: "if else for foreach while do switch case default break continue return goto try catch finally throw",
            types: "bool byte sbyte char decimal double float int uint long ulong short ushort object string void dynamic Task List Dictionary IEnumerable IList IDictionary Array Nullable Span Action Func DateTime Guid Exception",
            constants: "true false null",
            builtins: "Console WriteLine ReadLine ToString Equals GetHashCode nameof",
            rules: [RegexRule("^[ \\t]*#[ \\t]*[a-z]+", .preprocessor, options: [.anchorsMatchLines]),
                    RegexRule("\\[[A-Z][A-Za-z0-9_.]*(\\([^)]*\\))?\\]", .annotation)])
        cs.docLineComments = ["///"]
        cs.strings = [StringRule(open: "$\"", close: "\"", interpolationOpen: "{", interpolationClose: "}"),
                      StringRule(open: "@\"", close: "\"", escape: nil, multiline: true),
                      StringRule(open: "\""), StringRule(open: "'")]
        result.append(cs)

        // ---- Shaders & GPU --------------------------------------------------
        var metal = cpp
        metal.id = "metal"
        metal.name = "Metal Shading Language"
        metal.extensions = ["metal"]
        metal.keywords.formUnion(["kernel", "vertex", "fragment", "device", "constant", "threadgroup", "thread", "sampler", "texture2d", "texturecube", "buffer", "stage_in", "attribute"])
        metal.types.formUnion(["float2", "float3", "float4", "half", "half2", "half3", "half4", "int2", "int3", "int4", "uint2", "uint3", "uint4", "float4x4", "float3x3", "matrix"])
        result.append(metal)

        var glsl = LanguageDefinition.cLike(
            id: "glsl", name: "GLSL",
            extensions: ["glsl", "vert", "frag", "geom", "comp", "tesc", "tese"],
            keywords: "attribute const uniform varying layout centroid flat smooth noperspective patch sample subroutine in out inout invariant precision highp mediump lowp discard struct",
            types: "void bool int uint float double vec2 vec3 vec4 bvec2 bvec3 bvec4 ivec2 ivec3 ivec4 uvec2 uvec3 uvec4 mat2 mat3 mat4 sampler1D sampler2D sampler3D samplerCube image2D",
            constants: "true false gl_Position gl_FragColor gl_FragCoord gl_VertexID gl_InstanceID gl_PointSize",
            builtins: "abs sin cos tan pow exp log sqrt inversesqrt floor ceil fract mod min max clamp mix step smoothstep length distance dot cross normalize reflect refract texture texture2D textureCube dFdx dFdy",
            rules: [preprocessorRule])
        glsl.blockComments = [BlockComment("/*", "*/")]
        result.append(glsl)

        var hlsl = glsl
        hlsl.id = "hlsl"
        hlsl.name = "HLSL"
        hlsl.extensions = ["hlsl", "fx", "cginc", "compute", "shader"]
        hlsl.types.formUnion(["float2", "float3", "float4", "float4x4", "half", "min16float", "Texture2D", "SamplerState", "RWTexture2D", "StructuredBuffer"])
        hlsl.keywords.formUnion(["cbuffer", "tbuffer", "register", "technique", "pass", "SubShader", "Pass", "Properties"])
        result.append(hlsl)

        var cuda = cpp
        cuda.id = "cuda"
        cuda.name = "CUDA"
        cuda.extensions = ["cu", "cuh"]
        cuda.keywords.formUnion(["__global__", "__device__", "__host__", "__shared__", "__constant__", "__restrict__", "__syncthreads"])
        cuda.constants.formUnion(["threadIdx", "blockIdx", "blockDim", "gridDim", "warpSize"])
        result.append(cuda)

        // ---- Arduino / Processing -------------------------------------------
        var arduino = cpp
        arduino.id = "arduino"
        arduino.name = "Arduino"
        arduino.extensions = ["ino", "pde"]
        arduino.builtins.formUnion(["setup", "loop", "pinMode", "digitalWrite", "digitalRead", "analogWrite", "analogRead", "delay", "delayMicroseconds", "millis", "micros", "Serial", "map", "constrain"])
        arduino.constants.formUnion(["HIGH", "LOW", "INPUT", "OUTPUT", "INPUT_PULLUP", "LED_BUILTIN"])
        result.append(arduino)

        // ---- D ---------------------------------------------------------------
        var d = LanguageDefinition.cLike(
            id: "d", name: "D",
            extensions: ["d", "di"],
            keywords: "module import alias auto class struct union interface enum template mixin static final const immutable shared inout scope ref out in lazy pure nothrow @safe @trusted @system @nogc override abstract synchronized public private protected package export deprecated unittest version debug delegate function typeof typeid cast new delete this super is",
            controlKeywords: "if else for foreach foreach_reverse while do switch case default break continue return goto try catch finally throw with",
            types: "void bool byte ubyte short ushort int uint long ulong float double real char wchar dchar string wstring dstring size_t cent ucent",
            constants: "true false null __FILE__ __LINE__",
            rules: [RegexRule("@[a-zA-Z_][a-zA-Z0-9_]*", .annotation)])
        d.blockComments = [BlockComment("/**", "*/", doc: true), BlockComment("/*", "*/"), BlockComment("/+", "+/", nested: true)]
        result.append(d)

        // ---- Vala -------------------------------------------------------------
        var vala = LanguageDefinition.cLike(
            id: "vala", name: "Vala",
            extensions: ["vala", "vapi"],
            keywords: "using namespace class struct interface enum delegate signal construct static const abstract virtual override public private protected internal weak unowned owned out ref var new this base get set value async yield lock",
            types: "void bool char uchar int uint long ulong short ushort float double string size_t ssize_t unichar",
            constants: "true false null")
        result.append(vala)

        return result
    }
}
