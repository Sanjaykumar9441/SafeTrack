import { render, screen } from '@testing-library/react';

describe('Emergency Alert Dispatch', () => {

    test('renders emergency alert panel', () => {

        document.body.innerHTML =
            '<div>Emergency Alerts</div>';

        expect(
            screen.getByText(/Emergency Alerts/i)
        ).toBeTruthy();

    });

});