--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

Base64 = { }

do
	local concat = table.concat;
	local b = string.byte;
	local strchar = string.char
	local floor = math.floor

	local base64LU = {
		65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81,
		82, 83, 84, 85, 86, 87, 88, 89, 90, 97, 98, 99, 100, 101, 102, 103,
		104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116,
		117, 118, 119, 120, 121, 122, 48, 49, 50, 51, 52, 53, 54, 55, 56,
		57, 43, 47
	};

	local base64RLU = {
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, 62, -1, -1, -1, 63, 52, 53, 54, 55, 56, 57,
		58, 59, 60, 61, -1, -1, -1, -2, -1, -1, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8,
		9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, -1,
		-1, -1, -1, -1, -1, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38,
		39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1, -1
	};

	local shiftMul = {[18] = 262144, [12] = 4096, [6] = 64, [0] = 1};

	function Base64.encode(src)
		local dst = {};
		local srcLen = #src;
		local dstLen = 0;
		local n1 = 0;
		local n2 = srcLen - srcLen % 3;
		while (n1 < n2) do
			local n4 = n1;
			while (n4 < n2) do
				local c1, c2, c3 = b(src, n4 + 1, n4 + 3);
				local bits = c1 * 65536 + c2 * 256 + c3;
				n4 = n4 + 3;
				dstLen = dstLen + 1;
				dst[dstLen] = strchar(
					base64LU[floor(bits / 262144) + 1],
					base64LU[floor(bits / 4096) % 64 + 1],
					base64LU[floor(bits / 64) % 64 + 1],
					base64LU[bits % 64 + 1]
				);
			end
			n1 = n2;
		end
		if (n1 < srcLen) then
			local n4 = b(src, n1 + 1);
			n1 = n1 + 1;
			if (n1 == srcLen) then
				dstLen = dstLen + 1;
				dst[dstLen] = strchar(
					base64LU[floor(n4 / 4) + 1],
					base64LU[(n4 * 16) % 64 + 1],
					61,
					61
				);
			else
				local n5 = b(src, n1 + 1);
				dstLen = dstLen + 1;
				dst[dstLen] = strchar(
					base64LU[floor(n4 / 4) + 1],
					base64LU[(n4 * 16 + floor(n5 / 16)) % 64 + 1],
					base64LU[(n5 * 4) % 64 + 1],
					61
				);
			end
		end
		return concat(dst);
	end

	function Base64.decode(src)
		local dst = {};
		local srcLen = #src;
		local dstLen = 0;
		pcall(function()
			local n1 = 0;
			local n2 = 0;
			local n3 = 18;
			while (n1 < srcLen) do
				if ((n3 == 18) and (n1 + 4 < srcLen)) then
					local remaining = srcLen - n1;
					local n4 = n1 + remaining - remaining % 16;
					while (n1 < n4) do
						local c1,c2,c3,c4,c5,c6,c7,c8,c9,c10,c11,c12,c13,c14,c15,c16 = b(src, n1+1, n1+16);
						local v1 = base64RLU[c1+1]; local v2 = base64RLU[c2+1];
						local v3 = base64RLU[c3+1]; local v4 = base64RLU[c4+1];
						local v5 = base64RLU[c5+1]; local v6 = base64RLU[c6+1];
						local v7 = base64RLU[c7+1]; local v8 = base64RLU[c8+1];
						local v9 = base64RLU[c9+1]; local v10 = base64RLU[c10+1];
						local v11 = base64RLU[c11+1]; local v12 = base64RLU[c12+1];
						local v13 = base64RLU[c13+1]; local v14 = base64RLU[c14+1];
						local v15 = base64RLU[c15+1]; local v16 = base64RLU[c16+1];
						if v1<0 or v2<0 or v3<0 or v4<0 or v5<0 or v6<0 or v7<0 or v8<0
						or v9<0 or v10<0 or v11<0 or v12<0 or v13<0 or v14<0 or v15<0 or v16<0 then
							break;
						end
						n1 = n1 + 16;
						local va = v1*262144 + v2*4096 + v3*64 + v4;
						local vb = v5*262144 + v6*4096 + v7*64 + v8;
						local vc = v9*262144 + v10*4096 + v11*64 + v12;
						local vd = v13*262144 + v14*4096 + v15*64 + v16;
						dstLen = dstLen + 1;
						dst[dstLen] = strchar(
							floor(va/65536), floor(va/256)%256, va%256,
							floor(vb/65536), floor(vb/256)%256, vb%256,
							floor(vc/65536), floor(vc/256)%256, vc%256,
							floor(vd/65536), floor(vd/256)%256, vd%256
						);
					end
					remaining = srcLen - n1;
					n4 = n1 + remaining - remaining % 4;
					while (n1 < n4) do
						local c1, c2, c3, c4 = b(src, n1+1, n1+4);
						local b1 = base64RLU[c1+1];
						local b2 = base64RLU[c2+1];
						local b3 = base64RLU[c3+1];
						local b4 = base64RLU[c4+1];
						if ((b1 < 0) or (b2 < 0) or (b3 < 0) or (b4 < 0)) then
							break;
						end
						n1 = n1 + 4;
						local n5 = b1*262144 + b2*4096 + b3*64 + b4;
						dstLen = dstLen + 1;
						dst[dstLen] = strchar(
							floor(n5/65536),
							floor(n5/256) % 256,
							n5 % 256
						);
					end
					if (n1 >= srcLen) then
						break;
					end
				end
				n1 = n1 + 1;
				local n4 = b(src, n1);
				if (n4 == 61) then
					break;
				end
				n4 = base64RLU[n4 + 1];
				n2 = n2 + n4 * shiftMul[n3];
				n3 = n3 - 6;
				if (n3 < 0) then
					dstLen = dstLen + 1;
					dst[dstLen] = strchar(
						floor(n2 / 65536),
						floor(n2 / 256) % 256,
						n2 % 256
					);
					n3 = 18;
					n2 = 0;
				end
			end
			if (n3 == 6) then
				dstLen = dstLen + 1;
				dst[dstLen] = strchar(floor(n2 / 65536));
			elseif (n3 == 0) then
				dstLen = dstLen + 1;
				dst[dstLen] = strchar(
					floor(n2 / 65536),
					floor(n2 / 256) % 256
				);
			end
		end)
		return concat(dst);
	end

end
