public class Planet {
	static final double G = 6.67e-11;
	public double xxPos;
	public double yyPos;
	public double xxVel;
	public double yyVel;
	public double mass;
	public String imgFileName;
	public Planet(double xP,double yP,double xV,double yV,double m,String img) {
		xxPos = xP;
		yyPos = yP;
		xxVel = xV;
		yyVel = yV;
		mass = m;
		imgFileName = img;
	}
	public Planet(Planet p) {
		xxPos = p.xxPos;
		yyPos = p.yyPos;
		xxVel = p.xxVel;
		yyVel = p.yyVel;
		mass = p.mass;
		imgFileName = p.imgFileName;
	}
	public double calcDistance(Planet another) {
		double tmpX = xxPos - another.xxPos;
		double tmpY = yyPos - another.yyPos;
		return Math.sqrt(tmpX * tmpX + tmpY * tmpY);
	}
	public double calcForceExertedBy(Planet another) {
		double distance = calcDistance(another);
		return (G * mass * another.mass)/(distance * distance);
		
	}
	public double calcForceExertedByX (Planet another) {
		double dx = another.xxPos - xxPos;
		double distance = calcDistance(another);
		double force = calcForceExertedBy(another);
		return (force * dx)/distance;
	}
	public double calcForceExertedByY(Planet another) {
		double dy = another.yyPos - yyPos;
		double distance = calcDistance(another);
		double force = calcForceExertedBy(another);
		return (force * dy)/distance;
		
	}
	public double calcNetForceExertedByX (Planet[] allPlanets) {
		double netForceX = 0.0;
		for(Planet p:allPlanets) {
			if(this == p)
				continue;
			netForceX += calcForceExertedByX(p);
		}
		return netForceX;
	}
	public double calcNetForceExertedByY (Planet[] allPlanets) {
		double netForceY = 0.0;
		for(Planet p:allPlanets) {
			if(this == p)
				continue;
			netForceY += calcForceExertedByY(p);
		}
		return netForceY;
	}
	public void update(double dt,double fX,double fY) {
		xxVel += dt * (fX / mass);
		yyVel += dt * (fY / mass);
		xxPos += xxVel * dt;
		yyPos += yyVel * dt;
	}
	public void draw(){
		StdDraw.picture(xxPos,yyPos,"./images/" + imgFileName);
	}
}

