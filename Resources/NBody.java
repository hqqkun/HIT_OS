public class NBody {
	public static void main(String[] args) {
		double T = Double.parseDouble(args[0]);
		double dt = Double.parseDouble(args[1]);
		String fileName = args[2];
		double universeRadius = NBody.readRadius(fileName);
		Planet[] planets = NBody.readPlanets(fileName);
		double[] xForces = new double[planets.length];
		double[] yForces = new double[planets.length];

		final String backGround = "./images/starfield.jpg";
		StdDraw.setScale(-universeRadius, universeRadius);	
		drawHole(backGround, planets);
		StdDraw.enableDoubleBuffering();
		
		for(double time = 0.0; time < T;time += dt) {
			
			for(int i = 0; i != planets.length; ++i) {
				xForces[i] = planets[i].calcNetForceExertedByX(planets);
				yForces[i] = planets[i].calcNetForceExertedByY(planets);
			}
			for(int i = 0; i != planets.length; ++i) {
				planets[i].update(dt, xForces[i], yForces[i]);
			}
			drawHole(backGround, planets);
			StdDraw.show();
			StdDraw.pause(10);
		}

		StdOut.printf("%d\n", planets.length);
		StdOut.printf("%.2e\n", universeRadius);
		for (int i = 0; i < planets.length; i++) {
    	StdOut.printf("%11.4e %11.4e %11.4e %11.4e %11.4e %12s\n",
                  planets[i].xxPos, planets[i].yyPos, planets[i].xxVel,
                  planets[i].yyVel, planets[i].mass, planets[i].imgFileName);   
		}
		
		
	}

	public static void drawHole(String backGround,Planet[] planets) {
		StdDraw.clear();
		StdDraw.picture(0, 0, backGround);
		for(Planet p:planets){
			p.draw();
		}
		
	}
	public static double readRadius(String fileName) {
		In in = new In(fileName);
		int numPlanets = in.readInt();
		return in.readDouble();
	}
	public static Planet[] readPlanets(String fileName) {
		In in = new In(fileName);
		int numPlanets = in.readInt();
		double universeRadius = in.readDouble();
		Planet[] planets = new Planet[numPlanets];
		
		/** temp values */
		double xxPos,yyPos,xxVel,yyVel,mass;
		String imgFileName;
		
		for(int i = 0; i != numPlanets; ++i) {
			xxPos = in.readDouble();
			yyPos = in.readDouble();
			xxVel = in.readDouble();
			yyVel = in.readDouble();
			mass = in.readDouble();
			imgFileName = in.readString();
			planets[i] = new Planet(xxPos, yyPos, xxVel, yyVel, mass, imgFileName);
		}
		return planets;
	}
}
