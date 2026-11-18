//
//  ViewController.m
//  Parkiny
//
//  Created by Ebtisam Khalid on 22/04/2026.
//

#import "ViewController.h"
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

static NSString * const kParkedLatitudeKey = @"ParkedLatitude";
static NSString * const kParkedLongitudeKey = @"ParkedLongitude";

static UIColor *ParkinyArmorRed(void) {
    return [UIColor colorWithRed:0.698 green:0.078 blue:0.102 alpha:1.0];
}

static UIColor *ParkinyArmorGold(void) {
    return [UIColor colorWithRed:0.925 green:0.745 blue:0.278 alpha:1.0];
}

static UIColor *ParkinyArmorInk(void) {
    return [UIColor colorWithRed:0.09 green:0.075 blue:0.08 alpha:1.0];
}

@interface ViewController () <CLLocationManagerDelegate, MKMapViewDelegate>

@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) UIButton *saveLocationButton;
@property (nonatomic, strong) UIButton *showRouteButton;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UIButton *locateButton;
@property (nonatomic, strong) UILabel *placeLabel;
@property (nonatomic, strong) UILabel *coordinateLabel;
@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) CLGeocoder *geocoder;
@property (nonatomic, strong, nullable) CLLocation *parkedLocation;
@property (nonatomic, strong, nullable) CLLocation *lastGeocodedLocation;
@property (nonatomic, copy) NSString *currentPlaceName;
@property (nonatomic, strong, nullable) MKPointAnnotation *parkedAnnotation;
@property (nonatomic, strong, nullable) MKPolyline *activeRouteOverlay;
@property (nonatomic, assign) NSInteger routeRequestID;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = ParkinyArmorInk();
    [self setupMap];
    [self setupControls];
    [self setupLocationManager];
    [self restoreParkedLocationIfAvailable];
}

- (void)setupMap {
    self.mapView = [[MKMapView alloc] initWithFrame:CGRectZero];
    self.mapView.translatesAutoresizingMaskIntoConstraints = NO;
    self.mapView.delegate = self;
    self.mapView.showsUserLocation = YES;
    self.mapView.userTrackingMode = MKUserTrackingModeFollow;
    [self.view addSubview:self.mapView];

    [NSLayoutConstraint activateConstraints:@[
        [self.mapView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.mapView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.mapView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.mapView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (UIButton *)armorButtonWithTitle:(NSString *)title
                              symbol:(NSString *)symbolName
                               filled:(BOOL)filled
                               action:(SEL)action {
    UIButtonConfiguration *configuration = filled
        ? [UIButtonConfiguration filledButtonConfiguration]
        : [UIButtonConfiguration borderedButtonConfiguration];
    configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    configuration.title = title;
    configuration.image = [UIImage systemImageNamed:symbolName];
    configuration.imagePadding = 8.0;
    configuration.imagePlacement = NSDirectionalRectEdgeLeading;
    configuration.baseBackgroundColor = filled ? ParkinyArmorGold() : UIColor.clearColor;
    configuration.baseForegroundColor = filled ? ParkinyArmorInk() : ParkinyArmorGold();
    UIBackgroundConfiguration *background = configuration.background;
    background.strokeColor = ParkinyArmorGold();
    background.strokeWidth = filled ? 0.0 : 1.5;
    configuration.background = background;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(14.0, 18.0, 14.0, 18.0);
    configuration.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> *(NSDictionary<NSAttributedStringKey, id> *incoming) {
        NSMutableDictionary<NSAttributedStringKey, id> *attributes = [incoming mutableCopy];
        attributes[NSFontAttributeName] = [UIFont systemFontOfSize:17.0 weight:UIFontWeightBold];
        return attributes;
    };

    UIButton *button = [UIButton buttonWithConfiguration:configuration primaryAction:nil];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:52.0].active = YES;
    return button;
}

- (void)setupControls {
    self.saveLocationButton = [self armorButtonWithTitle:@"Save Spot"
                                                   symbol:@"parkingsign"
                                                    filled:YES
                                                    action:@selector(saveLocationTapped)];
    self.showRouteButton = [self armorButtonWithTitle:@"Route Back"
                                                symbol:@"arrow.triangle.turn.up.right.diamond"
                                                 filled:NO
                                                 action:@selector(showRouteTapped)];

    self.placeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.placeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.placeLabel.numberOfLines = 2;
    self.placeLabel.textAlignment = NSTextAlignmentCenter;
    self.placeLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    self.placeLabel.textColor = ParkinyArmorGold();
    self.placeLabel.text = @"Waiting for your location";

    self.coordinateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.coordinateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.coordinateLabel.numberOfLines = 1;
    self.coordinateLabel.textAlignment = NSTextAlignmentCenter;
    self.coordinateLabel.font = [UIFont monospacedDigitSystemFontOfSize:13.0 weight:UIFontWeightMedium];
    self.coordinateLabel.textColor = [ParkinyArmorGold() colorWithAlphaComponent:0.82];
    self.coordinateLabel.text = @"Coordinates show up here.";

    self.infoLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.infoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.infoLabel.numberOfLines = 0;
    self.infoLabel.textAlignment = NSTextAlignmentCenter;
    self.infoLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    self.infoLabel.textColor = ParkinyArmorGold();
    self.infoLabel.text = @"Park, then tap Save Spot.";

    UIStackView *placeStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.placeLabel, self.coordinateLabel]];
    placeStack.translatesAutoresizingMaskIntoConstraints = NO;
    placeStack.axis = UILayoutConstraintAxisVertical;
    placeStack.spacing = 2.0;
    placeStack.alignment = UIStackViewAlignmentFill;

    UIStackView *buttonStack = [[UIStackView alloc] initWithArrangedSubviews:@[placeStack, self.saveLocationButton, self.showRouteButton, self.infoLabel]];
    buttonStack.translatesAutoresizingMaskIntoConstraints = NO;
    buttonStack.axis = UILayoutConstraintAxisVertical;
    buttonStack.spacing = 12.0;
    buttonStack.alignment = UIStackViewAlignmentFill;

    UIView *dock = [[UIView alloc] initWithFrame:CGRectZero];
    dock.translatesAutoresizingMaskIntoConstraints = NO;
    dock.backgroundColor = [ParkinyArmorInk() colorWithAlphaComponent:0.94];
    dock.layer.cornerRadius = 28.0;
    dock.layer.borderWidth = 1.0;
    dock.layer.borderColor = [ParkinyArmorGold() colorWithAlphaComponent:0.85].CGColor;
    dock.layer.shadowColor = UIColor.blackColor.CGColor;
    dock.layer.shadowOpacity = 0.35;
    dock.layer.shadowRadius = 16.0;
    dock.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    [dock addSubview:buttonStack];
    [self.view addSubview:dock];

    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    NSLayoutConstraint *preferredDockWidth = [dock.widthAnchor constraintEqualToAnchor:safeArea.widthAnchor constant:-32.0];
    preferredDockWidth.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [dock.leadingAnchor constraintGreaterThanOrEqualToAnchor:safeArea.leadingAnchor constant:16.0],
        [dock.trailingAnchor constraintLessThanOrEqualToAnchor:safeArea.trailingAnchor constant:-16.0],
        [dock.centerXAnchor constraintEqualToAnchor:safeArea.centerXAnchor],
        [dock.widthAnchor constraintLessThanOrEqualToConstant:440.0],
        preferredDockWidth,
        [dock.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor constant:-8.0],

        [buttonStack.topAnchor constraintEqualToAnchor:dock.topAnchor constant:16.0],
        [buttonStack.leadingAnchor constraintEqualToAnchor:dock.leadingAnchor constant:16.0],
        [buttonStack.trailingAnchor constraintEqualToAnchor:dock.trailingAnchor constant:-16.0],
        [buttonStack.bottomAnchor constraintEqualToAnchor:dock.bottomAnchor constant:-16.0]
    ]];

    self.backButton = [self armorButtonWithTitle:@"Back"
                                          symbol:@"chevron.left"
                                           filled:YES
                                           action:@selector(backTapped)];
    self.backButton.hidden = YES;
    self.backButton.alpha = 0.0;
    [self.view addSubview:self.backButton];
    self.locateButton = [self iconButtonWithSymbol:@"location.fill" action:@selector(locateTapped)];
    self.locateButton.accessibilityLabel = @"Center on me";
    [self.view addSubview:self.locateButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.backButton.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:8.0],
        [self.backButton.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:16.0],
        [self.locateButton.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:8.0],
        [self.locateButton.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-16.0]
    ]];
}

- (UIButton *)iconButtonWithSymbol:(NSString *)symbolName action:(SEL)action {
    UIButtonConfiguration *configuration = [UIButtonConfiguration filledButtonConfiguration];
    configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    configuration.image = [UIImage systemImageNamed:symbolName];
    configuration.baseBackgroundColor = [ParkinyArmorInk() colorWithAlphaComponent:0.94];
    configuration.baseForegroundColor = ParkinyArmorGold();
    UIBackgroundConfiguration *background = configuration.background;
    background.strokeColor = ParkinyArmorGold();
    background.strokeWidth = 1.5;
    configuration.background = background;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(12.0, 12.0, 12.0, 12.0);

    UIButton *button = [UIButton buttonWithConfiguration:configuration primaryAction:nil];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.widthAnchor constraintEqualToConstant:48.0].active = YES;
    [button.heightAnchor constraintEqualToConstant:48.0].active = YES;
    return button;
}

- (void)setupLocationManager {
    self.geocoder = [[CLGeocoder alloc] init];
    self.currentPlaceName = @"";
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    [self.locationManager requestWhenInUseAuthorization];
    [self.locationManager startUpdatingLocation];
}

- (void)restoreParkedLocationIfAvailable {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (![defaults objectForKey:kParkedLatitudeKey] || ![defaults objectForKey:kParkedLongitudeKey]) {
        return;
    }

    CLLocationDegrees latitude = [defaults doubleForKey:kParkedLatitudeKey];
    CLLocationDegrees longitude = [defaults doubleForKey:kParkedLongitudeKey];
    self.parkedLocation = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
    [self updateParkedAnnotation];
    [self updateDistanceAndDirection];
}

- (void)saveLocationTapped {
    CLLocation *current = self.locationManager.location;
    if (!current) {
        self.infoLabel.text = @"Current location unavailable. Wait a moment and try again.";
        return;
    }

    self.parkedLocation = [[CLLocation alloc] initWithLatitude:current.coordinate.latitude longitude:current.coordinate.longitude];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setDouble:self.parkedLocation.coordinate.latitude forKey:kParkedLatitudeKey];
    [defaults setDouble:self.parkedLocation.coordinate.longitude forKey:kParkedLongitudeKey];
    [defaults synchronize];

    [self leaveRouteAndFollowUser];
    [self updateParkedAnnotation];
    [self updateDistanceAndDirection];
}

- (void)showRouteTapped {
    if (!self.parkedLocation) {
        self.infoLabel.text = @"Save a parking location first.";
        return;
    }

    CLLocation *current = self.locationManager.location;
    if (!current) {
        self.infoLabel.text = @"Current location unavailable. Unable to build route.";
        return;
    }

    MKPlacemark *sourcePlacemark = [[MKPlacemark alloc] initWithCoordinate:current.coordinate];
    MKMapItem *sourceItem = [[MKMapItem alloc] initWithPlacemark:sourcePlacemark];
    MKPlacemark *destinationPlacemark = [[MKPlacemark alloc] initWithCoordinate:self.parkedLocation.coordinate];
    MKMapItem *destinationItem = [[MKMapItem alloc] initWithPlacemark:destinationPlacemark];

    MKDirectionsRequest *request = [[MKDirectionsRequest alloc] init];
    request.source = sourceItem;
    request.destination = destinationItem;
    request.transportType = MKDirectionsTransportTypeAutomobile;
    request.requestsAlternateRoutes = NO;

    self.showRouteButton.enabled = NO;
    self.infoLabel.text = @"Finding a driving route…";

    MKDirections *directions = [[MKDirections alloc] initWithRequest:request];
    NSInteger requestID = ++self.routeRequestID;
    __weak typeof(self) weakSelf = self;
    [directions calculateDirectionsWithCompletionHandler:^(MKDirectionsResponse * _Nullable response, NSError * _Nullable error) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.routeRequestID != requestID) {
            return;
        }

        strongSelf.showRouteButton.enabled = YES;
        if (error || response.routes.count == 0) {
            strongSelf.infoLabel.text = @"Could not calculate route right now.";
            return;
        }

        MKRoute *route = response.routes.firstObject;
        [strongSelf.mapView removeOverlays:strongSelf.mapView.overlays];
        strongSelf.activeRouteOverlay = route.polyline;
        [strongSelf.mapView addOverlay:route.polyline];
        strongSelf.mapView.userTrackingMode = MKUserTrackingModeNone;
        [strongSelf.mapView setVisibleMapRect:route.polyline.boundingMapRect
                                  edgePadding:UIEdgeInsetsMake(120.0, 40.0, 300.0, 40.0)
                                     animated:YES];
        [strongSelf setBackButtonVisible:YES];

        NSString *direction = [strongSelf directionStringFromCoordinate:current.coordinate toCoordinate:strongSelf.parkedLocation.coordinate];
        strongSelf.infoLabel.text = [NSString stringWithFormat:@"Route ready. %@ %@.", [strongSelf distanceTextForMeters:route.distance], direction];
    }];
}

- (void)backTapped {
    [self leaveRouteAndFollowUser];
}

- (void)locateTapped {
    CLLocation *current = self.locationManager.location;
    if (!current) {
        self.infoLabel.text = @"Still waiting for your location.";
        return;
    }

    if (self.activeRouteOverlay) {
        MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(current.coordinate, 800.0, 800.0);
        [self.mapView setRegion:region animated:YES];
        return;
    }

    self.mapView.userTrackingMode = MKUserTrackingModeFollow;
}

- (void)leaveRouteAndFollowUser {
    self.routeRequestID += 1;
    [self.mapView removeOverlays:self.mapView.overlays];
    self.activeRouteOverlay = nil;
    [self setBackButtonVisible:NO];
    self.mapView.userTrackingMode = MKUserTrackingModeFollow;
    self.showRouteButton.enabled = YES;
    if (self.parkedLocation && self.locationManager.location) {
        [self updateDistanceAndDirection];
    } else if (!self.parkedLocation) {
        self.infoLabel.text = @"Park, then tap Save Spot.";
    }
}

- (void)setBackButtonVisible:(BOOL)visible {
    if (visible) {
        self.backButton.hidden = NO;
    }
    [UIView animateWithDuration:0.25 animations:^{
        self.backButton.alpha = visible ? 1.0 : 0.0;
    } completion:^(BOOL finished) {
        self.backButton.hidden = !visible;
    }];
}

- (void)updateParkedAnnotation {
    if (!self.parkedLocation) {
        return;
    }

    if (self.parkedAnnotation) {
        [self.mapView removeAnnotation:self.parkedAnnotation];
    }

    self.parkedAnnotation = [[MKPointAnnotation alloc] init];
    self.parkedAnnotation.coordinate = self.parkedLocation.coordinate;
    self.parkedAnnotation.title = @"Parked Car";
    self.parkedAnnotation.subtitle = [NSString stringWithFormat:@"%.5f, %.5f",
                                      self.parkedLocation.coordinate.latitude,
                                      self.parkedLocation.coordinate.longitude];
    [self.mapView addAnnotation:self.parkedAnnotation];
}

- (void)updateDistanceAndDirection {
    if (self.activeRouteOverlay) {
        return;
    }

    CLLocation *current = self.locationManager.location;
    if (!current || !self.parkedLocation) {
        return;
    }

    CLLocationDistance distanceMeters = [current distanceFromLocation:self.parkedLocation];
    NSString *direction = [self directionStringFromCoordinate:current.coordinate toCoordinate:self.parkedLocation.coordinate];
    self.infoLabel.text = [NSString stringWithFormat:@"%@ %@", [self distanceTextForMeters:distanceMeters], direction];
}

- (NSString *)distanceTextForMeters:(CLLocationDistance)meters {
    if (meters >= 1000.0) {
        return [NSString stringWithFormat:@"%.1f km", meters / 1000.0];
    }
    return [NSString stringWithFormat:@"%.0f m", meters];
}

- (NSString *)directionStringFromCoordinate:(CLLocationCoordinate2D)fromCoordinate toCoordinate:(CLLocationCoordinate2D)toCoordinate {
    double lat1 = fromCoordinate.latitude * M_PI / 180.0;
    double lat2 = toCoordinate.latitude * M_PI / 180.0;
    double dLon = (toCoordinate.longitude - fromCoordinate.longitude) * M_PI / 180.0;

    double y = sin(dLon) * cos(lat2);
    double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    double bearing = atan2(y, x) * 180.0 / M_PI;
    bearing = fmod((bearing + 360.0), 360.0);

    NSArray<NSString *> *cardinals = @[@"N", @"NE", @"E", @"SE", @"S", @"SW", @"W", @"NW"];
    NSInteger index = (NSInteger)lround(bearing / 45.0) % cardinals.count;
    return cardinals[index];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
    CLAuthorizationStatus status = manager.authorizationStatus;
    if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
        self.placeLabel.text = @"Location is off";
        self.coordinateLabel.text = @"Enable Parkiny in Settings.";
        self.infoLabel.text = @"Location access is required to save a spot.";
        return;
    }

    if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [self.locationManager startUpdatingLocation];
        [self refreshCurrentPlace];
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    if (error.code == kCLErrorDenied || manager.location) {
        return;
    }

    self.placeLabel.text = @"Location unavailable";
    self.coordinateLabel.text = @"Turn on Location Services and try again.";
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    if (locations.count == 0) {
        return;
    }
    [self refreshCurrentPlace];
    [self updateDistanceAndDirection];
}

- (void)refreshCurrentPlace {
    CLLocation *current = self.locationManager.location;
    if (!current) {
        return;
    }

    self.coordinateLabel.text = [NSString stringWithFormat:@"%.5f, %.5f", current.coordinate.latitude, current.coordinate.longitude];
    if (self.lastGeocodedLocation && [current distanceFromLocation:self.lastGeocodedLocation] < 200.0) {
        return;
    }
    if (self.geocoder.isGeocoding) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self.geocoder reverseGeocodeLocation:current completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (error || placemarks.count == 0) {
            if (strongSelf.currentPlaceName.length == 0) {
                strongSelf.placeLabel.text = @"Location found";
            }
            return;
        }

        CLPlacemark *place = placemarks.firstObject;
        strongSelf.lastGeocodedLocation = current;
        NSString *city = place.locality ?: place.subAdministrativeArea ?: place.name;
        NSString *country = place.country;
        if (city.length > 0 && country.length > 0) {
            strongSelf.currentPlaceName = [NSString stringWithFormat:@"%@, %@", city, country];
        } else {
            strongSelf.currentPlaceName = city.length > 0 ? city : (country.length > 0 ? country : @"Location found");
        }
        strongSelf.placeLabel.text = strongSelf.currentPlaceName;
    }];
}

#pragma mark - MKMapViewDelegate

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    if ([annotation isKindOfClass:MKUserLocation.class]) {
        return nil;
    }

    static NSString * const identifier = @"ParkedPin";
    MKMarkerAnnotationView *marker = (MKMarkerAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:identifier];
    if (!marker) {
        marker = [[MKMarkerAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:identifier];
        marker.canShowCallout = YES;
    }
    marker.annotation = annotation;
    marker.markerTintColor = ParkinyArmorRed();
    marker.glyphTintColor = ParkinyArmorGold();
    marker.glyphText = @"P";
    return marker;
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
    if (![overlay isKindOfClass:MKPolyline.class]) {
        return [[MKOverlayRenderer alloc] initWithOverlay:overlay];
    }

    MKPolylineRenderer *renderer = [[MKPolylineRenderer alloc] initWithPolyline:(MKPolyline *)overlay];
    renderer.strokeColor = ParkinyArmorGold();
    renderer.lineWidth = 6.0;
    return renderer;
}


@end
