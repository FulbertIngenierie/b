//-----------------------------------------------------------------------------
// Torque
// Copyright GarageGames, LLC 2011
//-----------------------------------------------------------------------------

singleton Material(DECAL_scorch)
{
   baseTex[0] = "";
   vertColor[ 0 ] = true;

   translucent = true;
   translucentBlendOp = None;
   translucentZWrite = true;
   alphaTest = true;
   alphaRef = 84;
   mapTo = "scorch_decal.png";
   diffuseMap[0] = "art/decals/scorch_decal.png";
   vertColor[0] = "1";
   materialTag0 = "Decals";
};

singleton Material(DECAL_RocketEXP)
{
   translucent = true;
   translucentBlendOp = LerpAlpha;
   translucentZWrite = true;
   mapTo = "rBlast.png";
   diffuseMap[0] = "art/decals/rBlast.png";
   vertColor[ 0 ] = true;
   castShadows = "0";
   vertColor[0] = "1";
   materialTag0 = "Decals";
};

singleton Material(DECAL_BulletHole)
{
   translucent = true;
   translucentBlendOp = LerpAlpha;
   translucentZWrite = true;
   mapTo = "bullet_hole.png";
   diffuseMap[0] = "art/decals/bullet_hole.png";
   vertColor[ 0 ] = true;
   castShadows = "0";
   vertColor[0] = "1";
   materialTag0 = "Decals";
};

singleton Material(DECAL_defaultblobshadow)
{
   baseTex[0] = "";

   translucent = true;
   translucentBlendOp = LerpAlpha;
   translucentZWrite = true;
   alphaTest = false;
   mapTo = "defaultblobshadow";
   diffuseMap[0] = "art/decals/defaultblobshadow";
   materialTag0 = "Decals";
   //alphaRef = 64;
   //emissive[0] = "1";
};
