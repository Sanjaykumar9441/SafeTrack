import '@testing-library/jest-dom';

import { render, screen } from '@testing-library/react';

describe('Emergency Alerts Panel', () => {

    test('renders emergency alerts title', () => {

        render(
            <div>Emergency Alerts</div>
        );

        expect(
            screen.getByText(/Emergency Alerts/i)
        ).toBeInTheDocument();

    });

});