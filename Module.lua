local function Area(Poly)
    local N = #Poly;
    local A = 0;
    local P = N - 1;
    for Q = 1, N, 2 do
        local L1, L2 = Poly[P], Poly[Q + 1];
        local R1, R2 = Poly[Q], Poly[P + 1];
        A = A + (L1  * L2 - R1 * R2);
        P = Q;
    end
    return A * 0.5;
end;

local function InsideTriangle(Ax, Ay, Bx, By, Cx, Cy, Px, Py)
    local ax = (Cx - Bx);
    local ay = (Cy - By);
    local bx = (Ax - Cx);
    local by = (Ay - Cy);
    local cx = (Bx - Ax);
    local cy = (By - Ay);
    local apx = (Px - Ax);
    local apy = (Py - Ay);
    local bpx = (Px - Bx);
    local bpy = (Px - By);
    local cpx = (Px - Cx);
    local cpy = (Px - Cy);

    local acbp = ax * bpy - ay * bpx;
    local bccp = cx * cpy - by * cpx;
    local ccap = cx * apy - cy * apx;
    
    return (acbp >= 0) and (bccp >= 0) and (ccap >= 0);
end;

local function Snip(C, U, V, W, N, V2)
    local Ax, Ay, Bx, By, Cx, Cy, Px, Py;

    Ax = C[V[U]];
    Ay = C[V[U] + 1];

    Bx = C[V[V2]];
    By = C[V[V2] + 1];

    Cx = C[V[W]];
    Cy = C[V[W] + 1];

    if (0.000001 > (((Bx - Ax) * (Cy - Ay)) - ((By - Ay) * (Cx - Ax)))) then
        return false;
    end;

    for p = 1, N do
        if not ((p == U) or (p == V) or (p == W)) then

            Px = C[V[p]];
            Py = C[V[p] + 1];

            if (InsideTriangle(Ax, Ay, Bx, By, Cx, Cy, Px, Py)) then
                return false;
            end;
        end;
    end

    return true;
end;

local function GroupByN(ToGroup, N)
    local Result = {};
    local Current = {};

    N = N or 3;

    for i, v in next, ToGroup do
        table.insert(Current, v);
        if (#Current >= N) then
            table.insert(Result, Current);
            Current = {};
        end;
    end

    return Result;
end;

local function Triangulate(Poly)
    local Result = {};
    local NV = math.floor(#Poly / 2);
    local V = {};

    if (#Poly < 6) then return end;

    if  Area(Poly) >= 0 then
        for I = 1, NV do
            V[I] = I * 2 - 1;
        end
    else
        for I = 1, NV do
            V[I] = #Poly - I * 2 + 1;
        end
    end;

    local Count = NV * 2;
    local V2 = NV;

    while (NV > 2) do
        Count = Count - 1;
        if (Count < 0) then
            return nil;
        end;
        local U = V2;
        if (U > NV) then U = 1 end;
        V2 = U + 1;
        if (V2 > NV) then V2 = 1 end;
        local W = V2 + 1;
        if (W > NV) then W = 1 end;
        if (Snip(Poly, U, V, W, NV, V2)) then
            local A, B, C = V[U], V[V2], V[W];
            
            table.insert(Result, Poly[A]); table.insert(Result, Poly[A + 1]);
            table.insert(Result, Poly[B]); table.insert(Result, Poly[B + 1]);
            table.insert(Result, Poly[C]); table.insert(Result, Poly[C + 1]);

            table.remove(V, V2);

            NV = NV - 1;
            Count = NV * 2;
        end;
    end

    return GroupByN(Result, 6), Area(Poly);
end;

local V2 = Vector2.new;

local StartPosition = game:GetService("Workspace").CurrentCamera.ViewportSize;
StartPosition = Vector2.new(StartPosition.X / 2, StartPosition.Y / 2);

local OldDrawing = Drawing;

local Drawing = {};
Drawing.Fonts = OldDrawing.Fonts;

function Drawing.new(Type)
    if (Type == "Polygon") then
        local function Triangle(A, B, C)
            local NewTriangle = OldDrawing.new("Triangle");
            NewTriangle.Visible = true;
            NewTriangle.PointA = StartPosition + A;
            NewTriangle.PointB = StartPosition + B;
            NewTriangle.PointC = StartPosition + C;
            NewTriangle.Color = Color3.fromRGB(255, 255, 255);
            NewTriangle.Filled = true;
            return NewTriangle;
        end;
        local PolygonMeta = {
            Sides = 0,
            Color = Color3.fromRGB(255, 255, 255),
            Area = 0,
            Visible = true
        };
        local DrawingObjects = {};
        return setmetatable({}, {
            __newindex = function(_, Index, Value)
                if ((Index == "Color") or (Index == "Colour")) then
                    table.foreach(DrawingObjects, function(_, V)
                        V.Color = Value;
                    end)
                elseif (Index == "Points") then
                    local Points = Value;
                    local TriangulatedNew, NewArea = Triangulate(Points);
                    if (TriangulatedNew) then
                        rawset(PolygonMeta, "Area", NewArea);
                        rawset(PolygonMeta, "Sides", (#Points / 2) - 1);
                        coroutine.wrap(function()
                            table.foreach(DrawingObjects, function(_, V)
                                V:Remove();
                            end)
                            for _, v in next, TriangulatedNew do
                                local Pa = V2(v[1], -v[2]);
                                local Pb = V2(v[3], -v[4]);
                                local Pc = V2(v[5], -v[6]);
                                local Triad = Triangle(Pa, Pb, Pc);
                                table.insert(DrawingObjects, Triad);
                            end
                        end)();
                    else
                        return warn("Error triangulating polygon.");
                    end
                elseif (Index == "Visible") then
                    if (not (Value == rawget(PolygonMeta, "Visible"))) then
                        table.foreach(DrawingObjects, function(_, V)
                            V.Visible = Value;
                        end)
                        rawset(PolygonMeta, "Visible", Value);
                    end
                end
            end;
            __index = function(_, Index)
                if (Index == "Remove" or Index == "Destroy") then
                    return function()
                        coroutine.wrap(function()
                            table.foreach(DrawingObjects, function(_, V)
                                V:Remove();
                            end)
                            table.clear(PolygonMeta);
                            setmetatable(PolygonMeta, {});
                        end)();
                    end
                end;
                return rawget(PolygonMeta, Index);
            end;
        });
    else
        return OldDrawing.new(Type);
    end
end;

return Drawing;
