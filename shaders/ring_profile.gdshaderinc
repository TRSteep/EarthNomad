// Measured radial boundaries: NASA/NSSDCA and PDS Ring-Moon Systems Node.
float ring_band(float r,float lo,float hi,float pixel) {
	return smoothstep(lo-pixel,lo+pixel,r)*(1.0-smoothstep(hi-pixel,hi+pixel,r));
}
float ring_noise(float x) {
	float k=floor(x); float f=fract(x); f=f*f*(3.0-2.0*f);
	return mix(fract(sin(k*127.1)*43758.5453),fract(sin((k+1.0)*127.1)*43758.5453),f);
}
float narrow_ring(float r,float center,float width,float tau,float pixel) {
	float w=max(width,pixel);
	return tau*min(width/w,1.0)*exp(-2.0*pow((r-center)/w,2.0));
}
vec4 ring_profile(int kind,float r,float theta,float pixel) {
	pixel=max(pixel,0.00003);
	if(kind==1) {
		float km=r*58232.0;
		float fine=mix(0.78,1.16,ring_noise(km*0.018));
		float broad=mix(0.65,1.2,ring_noise(km*0.0008));
		float tau=0.002*ring_band(km,66900.0,74510.0,pixel*58232.0);
		tau+=0.15*broad*ring_band(km,74658.0,91975.0,pixel*58232.0);
		tau+=1.3*broad*ring_band(km,91975.0,117507.0,pixel*58232.0);
		tau+=0.018*ring_noise(km*0.002)*ring_band(km,117507.0,122340.0,pixel*58232.0);
		tau+=0.62*broad*ring_band(km,122340.0,136780.0,pixel*58232.0);
		tau*=1.0-ring_band(km,133410.0,133735.0,pixel*58232.0);
		tau*=1.0-ring_band(km,136487.0,136529.0,pixel*58232.0);
		tau*=fine;
		tau+=narrow_ring(r,(139826.0+25.0*sin(theta*5.0))/58232.0,70.0/58232.0,0.32,pixel);
		vec3 tint=mix(vec3(0.37,0.32,0.26),vec3(0.86,0.79,0.65),smoothstep(84000.0,100000.0,km));
		tint*=mix(0.84,1.08,ring_noise(km*0.0019));
		return vec4(tint,tau);
	}
	if(kind==2) {
		float km=r*25362.0;
		float px=pixel*25362.0;
		float tau=0.0045*ring_band(km,37850.0,41350.0,px);
		tau+=narrow_ring(km,41838.0,1.53,0.3,px);
		tau+=narrow_ring(km,42234.0,2.28,0.5,px);
		tau+=narrow_ring(km,42571.0,2.33,0.3,px);
		tau+=narrow_ring(km,44718.0,8.46,0.4,px);
		tau+=narrow_ring(km,45661.0,9.49,0.3,px);
		tau+=narrow_ring(km,47176.0,1.6,0.4,px);
		tau+=narrow_ring(km,47627.0,2.15,0.3,px);
		tau+=narrow_ring(km,48300.0,4.6,0.5,px);
		tau+=narrow_ring(km,50024.0,2.3,0.1,px);
		float eps=51149.0*(1.0-0.00794*0.00794)/(1.0+0.00794*cos(theta));
		tau+=narrow_ring(km,eps,58.1+35.0*cos(theta),1.5,px);
		tau+=0.0000056*ring_band(km,65400.0,69200.0,px);
		tau+=0.0000085*ring_band(km,89200.0,106200.0,px);
		return vec4(0.26,0.24,0.22,tau);
	}
	return vec4(0.0);
}
