'use client';

import Spline from '@splinetool/react-spline';

// Replace this URL with your own Spline scene URL
// Get one from: https://spline.design (search for "brain" in community)
const SPLINE_SCENE_URL = 'https://prod.spline.design/6Wq1Q7YGyM-iab9i/scene.splinecode';

export function SplineBrain() {
  return (
    <div className="w-full h-[400px] md:h-[500px]">
      <Spline scene={SPLINE_SCENE_URL} />
    </div>
  );
}

